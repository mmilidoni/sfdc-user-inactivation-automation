public class UserInactivationBatch_mm implements Database.Batchable<sObject>, Database.Stateful {
    
    private List<String> recipients;
    private List<Database.SaveResult> frozenResult = new List<Database.SaveResult>();
    private Map<Id, Id> userLoginToUser = new Map<Id, Id>();
    
    public UserInactivationBatch_mm() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();

        if (ius.size() > 0) {
            if (String.isNotBlank(ius[0].Email_Recipient_mm__c)) {
                recipients = ius[0].Email_Recipient_mm__c.split(',');
            }
        }
    }
    public Database.QueryLocator start(Database.BatchableContext BC){
        return Database.getQueryLocator('SELECT Id, Freeze_Date_mm__c FROM User WHERE Freeze_Date_mm__c <= TODAY');
    }

    public void execute(Database.BatchableContext BC, List<User> users){
        Map<Id, User> userIdsMapToFreeze = new Map<Id, User>();
        Date today = System.today();
        for(User u : users){
            if (u.Freeze_Date_mm__c <= today) {
                u.Freeze_Date_mm__c = null;
                userIdsMapToFreeze.put(u.Id, u);
            }
        }
        
        if (userIdsMapToFreeze.size() > 0) {
            List<UserLogin> userLogins = [SELECT Id, IsFrozen, UserId 
            FROM UserLogin 
            WHERE UserId IN :userIdsMapToFreeze.keySet()];

            for (UserLogin ul : userLogins) {
                ul.IsFrozen = true;
                userLoginToUser.put(ul.Id, ul.UserId);
            }

            frozenResult.addAll(Database.update(userLogins, false));
        }
    }
   
    public void finish(Database.BatchableContext BC){

        if (frozenResult != null){
            String bodySuccesses = '';
            String bodyErrors = '';
            List<User> usersSuccess = new List<User>();
            for (Database.SaveResult r : frozenResult) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) { 
                        bodyErrors += e.getStatusCode() + ': ' + e.getMessage() + '<br />';
                    }
                } else {
                    bodySuccesses += 'UserLogin Id: ' + r.getId()  + '<br />';
                    usersSuccess.add(new User(
                        Id=userLoginToUser.get(r.getId()), 
                        Freeze_Date_mm__c = null)
                    );
                }
            }
            System.debug(usersSuccess.size() + ' users succesfully processed');
            update usersSuccess;

            if (recipients.size() > 0) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(recipients);
                mail.setSubject('User Freezing Report');
                mail.setHtmlBody('<h1>SUCCESS</h1>' + bodySuccesses + '<hr />' 
                + '<h1>ERRORS</h1>' + bodyErrors);
    
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        }
    }
  
}
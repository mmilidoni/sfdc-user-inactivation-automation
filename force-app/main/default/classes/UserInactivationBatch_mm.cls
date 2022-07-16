public class UserInactivationBatch_mm implements Database.Batchable<sObject>, Database.Stateful {
    
    private List<String> recipients;
    private List<Database.SaveResult> frozenResult = new List<Database.SaveResult>();
    private Map<Id, Id> userLoginToUser = new Map<Id, Id>();
    @TestVisible private Inactive_Users_Setting_mm__mdt inactiveUserSetting;
    public Date LAST_LOGIN_FREEZE_DATE;
    public Date LAST_LOGIN_INACTIVE_DATE;
    public static Integer batchSize = 200;
    
    public UserInactivationBatch_mm() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();

        if (ius != null && ius.size() > 0) {
            inactiveUserSetting = ius[0];
            if (String.isNotBlank(inactiveUserSetting.Email_Recipient_mm__c)) {
                recipients = inactiveUserSetting.Email_Recipient_mm__c.split(',');
            }
        }

        if (ius.size() > 0 && ius[0].Batch_Size_mm__c > 0) {
            batchSize = ius[0].Batch_Size_mm__c.intValue();
        }

        LAST_LOGIN_FREEZE_DATE = Date.today().addDays(-inactiveUserSetting.Freezing_Days_After_Last_Login_mm__c.intValue());
        LAST_LOGIN_INACTIVE_DATE = Date.today().addDays(-inactiveUserSetting.Inactivation_Days_After_Last_Login_mm__c.intValue());
    }
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String q = 'SELECT Id, LastLoginDate, Username, Skip_Freezing_mm__c, Skip_Inactivation_mm__c ' +
        'FROM User ' +
        'WHERE (Skip_Freezing_mm__c = false AND (LastLoginDate = NULL OR LastLoginDate <= :LAST_LOGIN_FREEZE_DATE)) ' +
            'OR (Skip_Inactivation_mm__c = false AND (LastLoginDate = NULL OR LastLoginDate <= :LAST_LOGIN_INACTIVE_DATE)) ';
        if (Test.isRunningTest()) {
                q += 'LIMIT :batchSize';
        }
        return Database.getQueryLocator(q);
    }

    public void execute(Database.BatchableContext BC, List<User> users){
        Map<Id, User> userIdsMapToFreeze = new Map<Id, User>();
        Date today = System.today();
        for(User u : users){
            if (u.Skip_Freezing_mm__c == false && (u.LastLoginDate == null || u.LastLoginDate <= LAST_LOGIN_FREEZE_DATE)) {
                u.Skip_Freezing_mm__c = null;
                userIdsMapToFreeze.put(u.Id, u);
            }
        }
        
        if (userIdsMapToFreeze.size() > 0) {
            List<UserLogin> userLogins = [SELECT Id, IsFrozen, UserId 
            FROM UserLogin 
            WHERE UserId IN :userIdsMapToFreeze.keySet()];

            for (UserLogin ul : userLogins) {
                userLoginToUser.put(ul.Id, ul.UserId);
            }

            frozenResult.addAll(Database.update(userLogins, false));

            System.debug(userIdsMapToFreeze.size() + ' users frozen');
        }
    }
   
    public void finish(Database.BatchableContext BC){

        if (frozenResult.size() > 0){
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
                        Skip_Freezing_mm__c = true)
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
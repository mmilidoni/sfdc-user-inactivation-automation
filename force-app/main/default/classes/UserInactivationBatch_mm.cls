public class UserInactivationBatch_mm implements Database.Batchable<sObject>, Database.Stateful {
    
    @TestVisible private List<String> recipients;
    private List<Database.SaveResult> frozenResult = new List<Database.SaveResult>();
    private List<Database.SaveResult> inactivatedResult = new List<Database.SaveResult>();
    private Map<Id, Id> userLoginToUser = new Map<Id, Id>();
    @TestVisible private Inactive_Users_Setting_mm__mdt inactiveUserSetting;
    public Date LAST_LOGIN_FREEZE_DATE;
    public Date LAST_LOGIN_INACTIVE_DATE;
    public static Integer batchSize = 200;
    
    public UserInactivationBatch_mm() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();

        if (ius != null && ius.size() > 0) {
            inactiveUserSetting = ius[0];
        } else {
            throw new UnexpectedException('No record with "Default" as name found into Inactive_Users_Setting_mm__mdt');
        }
        // retrieving email addresses for sending notification email
        if (String.isNotBlank(inactiveUserSetting.Email_Recipient_mm__c)) {
            recipients = inactiveUserSetting.Email_Recipient_mm__c.split(',');
        }
        // retrieving batch size
        if (inactiveUserSetting.Batch_Size_mm__c > 0) {
            batchSize = inactiveUserSetting.Batch_Size_mm__c.intValue();
        }
        
        LAST_LOGIN_FREEZE_DATE = Date.today().addDays(-inactiveUserSetting.Freezing_Days_After_Last_Login_mm__c.intValue());
        LAST_LOGIN_INACTIVE_DATE = Date.today().addDays(-inactiveUserSetting.Inactivation_Days_After_Last_Login_mm__c.intValue());
    }
    public Database.QueryLocator start(Database.BatchableContext BC) {
        String q = 'SELECT Id, LastLoginDate, Username, Skip_Freezing_mm__c, Skip_Inactivation_mm__c, IsActive ' +
        'FROM User ' +
        'WHERE IsActive = true AND Profile.Name <> \'System Administrator\' AND (Profile.UserLicense.Name = \'Salesforce\' OR Profile.UserLicense.Name = \'Salesforce Platform\') AND ((Skip_Freezing_mm__c = false AND (LastLoginDate = NULL OR DAY_ONLY(LastLoginDate) <= :LAST_LOGIN_FREEZE_DATE)) ' +
        'OR (Skip_Inactivation_mm__c = false AND (LastLoginDate = NULL OR DAY_ONLY(LastLoginDate) <= :LAST_LOGIN_INACTIVE_DATE))) ';

        if (String.isNotBlank(inactiveUserSetting.Excluded_Profiles_mm__c)) {
            Map<String, Profile> m = new Map<String, Profile>([SELECT Id FROM Profile WHERE Name IN :inactiveUserSetting.Excluded_Profiles_mm__c.split(',')]);
            String vals = '\'' + String.join(new List<String>(m.keySet()), '\',\'') + '\'';

            q += 'AND (NOT ProfileId IN (' + vals + ')) ';
        }
    
        if (Test.isRunningTest()) {
                q += 'LIMIT :batchSize';
        }
        System.debug(q);

        return Database.getQueryLocator(q);
    }

    public void execute(Database.BatchableContext BC, List<User> users){
        Map<Id, User> userIdsMapToFreeze = new Map<Id, User>();
        List<User> usersToInactivate = new List<User>();

        Date today = System.today();
        for(User u : users){
            // users to be inactivated
            if (u.Skip_Inactivation_mm__c == false && (u.LastLoginDate == null || u.LastLoginDate <= LAST_LOGIN_FREEZE_DATE)) {
                u.IsActive = false;
                u.Skip_Inactivation_mm__c = true;
                usersToInactivate.add(u);
            // users to be frozen            
            } else if (u.Skip_Freezing_mm__c == false && (u.LastLoginDate == null || u.LastLoginDate <= LAST_LOGIN_FREEZE_DATE)) {
                userIdsMapToFreeze.put(u.Id, u);
            }
        }

        if (userIdsMapToFreeze.size() > 0) {
            List<UserLogin> userLogins = [SELECT Id, IsFrozen, UserId 
            FROM UserLogin 
            WHERE UserId IN :userIdsMapToFreeze.keySet()];

            for (UserLogin ul : userLogins) {
                ul.IsFrozen = false;
                userLoginToUser.put(ul.Id, ul.UserId);
            }

            frozenResult.addAll(Database.update(userLogins, false));

            System.debug(userIdsMapToFreeze.size() + ' users frozen');
        }

        if (usersToInactivate.size() > 0) {
            inactivatedResult.addAll(Database.update(usersToInactivate, false));
            System.debug(usersToInactivate.size() + ' users inactivated');
        }
    }
   
    public void finish(Database.BatchableContext BC){

        if (frozenResult.size() > 0){
            String bodyFrozenSuccesses = '';
            String bodyFrozenErrors = '';
            List<User> usersFrozenSuccess = new List<User>();
            for (Database.SaveResult r : frozenResult) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) { 
                        bodyFrozenErrors += e.getStatusCode() + ': ' + e.getMessage() + '<br />';
                    }
                } else {
                    bodyFrozenSuccesses += 'UserLogin Id: ' + r.getId()  + '<br />';
                    usersFrozenSuccess.add(new User(
                        Id=userLoginToUser.get(r.getId()), 
                        Skip_Freezing_mm__c = true)
                    );
                }
            }
            System.debug(usersFrozenSuccess.size() + ' users succesfully processed');
            update usersFrozenSuccess;

            if (recipients != null && recipients.size() > 0) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(recipients);
                mail.setSubject('User Freezing Report');
                mail.setHtmlBody('<h1>SUCCESS</h1>' + bodyFrozenSuccesses + '<hr />' 
                + '<h1>ERRORS</h1>' + bodyFrozenErrors);
    
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        }
        if (inactivatedResult.size() > 0){
            String bodyInactivatedSuccesses = '';
            String bodyInactivatedErrors = '';
            for (Database.SaveResult r : inactivatedResult) {
                if (!r.isSuccess()) {
                    for (Database.Error e : r.getErrors()) { 
                        bodyInactivatedErrors += e.getStatusCode() + ': ' + e.getMessage() + '<br />';
                    }
                } else {
                    bodyInactivatedSuccesses += 'UserLogin Id: ' + r.getId()  + '<br />';
                }
            }

            if (recipients != null && recipients.size() > 0) {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(recipients);
                mail.setSubject('User Inactivation Report');
                mail.setHtmlBody('<h1>SUCCESS</h1>' + bodyInactivatedSuccesses + '<hr />' 
                + '<h1>ERRORS</h1>' + bodyInactivatedErrors);
    
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            }
        }

    }
  
}
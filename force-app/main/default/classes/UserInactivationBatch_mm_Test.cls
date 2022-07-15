@isTest
public class UserInactivationBatch_mm_Test {
    static testMethod void testFreezing() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();
        Integer batchSize = 200;
        if (ius.size() > 0 && ius[0].Batch_Size_mm__c > 0) {
            batchSize = ius[0].Batch_Size_mm__c.intValue();
        }

        List<User> lstUser= new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        for(Integer i=0; i < batchSize; i++) {
            User u = new User(Alias = 'stdm' + i, Email='standarduser' + i + '@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='michelemstandarduser' + i + '@testorg.com');
            u.Skip_Freezing_mm__c = math.mod(i, 2) == 0;
            lstUser.add(u);
        }
        
        insert lstUser;

        Test.startTest();

        UserInactivationBatch_mm obj = new UserInactivationBatch_mm();
        obj.LAST_LOGIN_FREEZE_DATE = Date.today().addDays(1);
        DataBase.executeBatch(obj, batchSize); 
        Test.stopTest();

        Map<Id, User> usrIdMap = new Map<Id, User>();
        for (User u : lstUser) {
            usrIdMap.put(u.Id, u);
        }
        
        
        for (UserLogin ul : [SELECT id, UserId, IsFrozen FROM UserLogin WHERE UserId IN :usrIdMap.keySet()]) {
            if (usrIdMap.get(ul.UserId).LastLoginDate >= obj.LAST_LOGIN_FREEZE_DATE) {
                System.assertEquals(ul.isFrozen, true);
            } else {
                System.assertEquals(ul.isFrozen, false);
            }
        }
    }
}
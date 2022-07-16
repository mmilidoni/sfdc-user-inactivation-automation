@isTest
public class UserInactivationBatch_mm_Test {
    static testMethod void testFreezing() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();

        List<User> lstUser= new List<User>();
        Integer skippedUsersCount = 0;
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        for(Integer i=0; i < UserInactivationBatch_mm.batchSize; i++) {
            User u = new User(Alias = 'stdm' + i, Email='standarduser' + i + '@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='michelemstandarduser' + i + '@testorg.com');
            u.Skip_Freezing_mm__c = math.mod(i, 2) == 0;
            if (u.Skip_Freezing_mm__c) {
                skippedUsersCount += 1;
            }
            lstUser.add(u);
        }
        
        Test.startTest();
        insert lstUser;
        System.debug(lstUser.size() + ' users generated');
        System.debug( skippedUsersCount + ' users skipped');

        UserInactivationBatch_mm obj = new UserInactivationBatch_mm();
        obj.LAST_LOGIN_FREEZE_DATE = Date.today().addDays(2);
        DataBase.executeBatch(obj, UserInactivationBatch_mm.batchSize); 
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
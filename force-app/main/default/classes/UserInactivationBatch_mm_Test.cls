@isTest
public class UserInactivationBatch_mm_Test {

    static testMethod void testAll() {        
        List<User> lstUser = new List<User>();
        Profile p = [SELECT Id FROM Profile WHERE Name='Standard User']; 
        for(Integer i=0; i < UserInactivationBatch_mm.batchSize; i++) {
            User u = new User(Alias = 'stdm' + i, Email='standarduser' + i + '@testorg.com', 
            EmailEncodingKey='UTF-8', LastName='Testing', LanguageLocaleKey='en_US', 
            LocaleSidKey='en_US', ProfileId = p.Id, 
            TimeZoneSidKey='America/Los_Angeles', UserName='michelemstandarduser' + i + '@testorg.com');
            u.Skip_Freezing_mm__c = getRandom();
            u.Skip_Inactivation_mm__c = getRandom();
            lstUser.add(u);
        }

        Test.startTest();
        insert lstUser;
        System.debug(lstUser.size() + ' users generated');

        UserInactivationBatch_mm obj = new UserInactivationBatch_mm();
        obj.LAST_LOGIN_FREEZE_DATE = Date.today().addDays(2);
        obj.LAST_LOGIN_INACTIVE_DATE = Date.today().addDays(2);
        DataBase.executeBatch(obj, UserInactivationBatch_mm.batchSize); 
        Test.stopTest();
    }

    private static Boolean getRandom() {
        return Math.mod(Integer.valueof((math.random() * 10)) , 2) == 0;
    }
}
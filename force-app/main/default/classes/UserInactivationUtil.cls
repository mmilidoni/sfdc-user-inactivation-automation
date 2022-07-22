public class UserInactivationUtil {

    public static Inactive_Users_Setting_mm__mdt getInactiveUserSettings() {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();

        if (ius != null && ius.size() > 0) {
            return ius[0];
        } else {
            throw new UnexpectedException('No record with "Default" as name found into Inactive_Users_Setting_mm__mdt');
        }
    }

    public static String getQuery(Date lastLoginFreezeDate, Date lastLoginInactiveDate, Boolean eq) {
        String operator = eq ? '=' : '<=';
        String q = 'SELECT Id, LastLoginDate, Username, Skip_Freezing_mm__c, Skip_Inactivation_mm__c, IsActive ' +
        'FROM User ' +
        'WHERE Profile.UserLicense.Name = \'Salesforce\' AND ((Skip_Freezing_mm__c = false AND (LastLoginDate = NULL OR DAY_ONLY(LastLoginDate) ' + operator + ' ' + String.valueOf(lastLoginFreezeDate) + ')) ' +
        'OR (Skip_Inactivation_mm__c = false AND (LastLoginDate = NULL OR DAY_ONLY(LastLoginDate) ' + operator + ' ' + String.valueOf(lastLoginInactiveDate) + '))) ';

        Inactive_Users_Setting_mm__mdt inactiveUserSetting = getInactiveUserSettings();

        if (String.isNotBlank(inactiveUserSetting.Excluded_Profiles_mm__c)) {
            // List<Profile> excludedProfiles = [SELECT Id FROM Profile WHERE Name IN :inactiveUserSetting.Excluded_Profiles_mm__c.split(',')]; 
            Map<String, Profile> m = new Map<String, Profile>([SELECT Id FROM Profile WHERE Name IN :inactiveUserSetting.Excluded_Profiles_mm__c.split(',')]);

            
            // System.debug(excludedProfiles);
            String vals = '\'' + String.join(new List<String>(m.keySet()), '\',\'') + '\'';


            q += 'AND (NOT ProfileId IN (' + vals + ')) ';
        }
    
        if (Test.isRunningTest()) {
                q += 'LIMIT :batchSize';
        }
        System.debug(q);

        return q;
    }
}

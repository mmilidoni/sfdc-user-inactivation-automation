public class UserInactivationSchedulable_mm implements Schedulable {
    public void execute(SchedulableContext sc) {
        List<Inactive_Users_Setting_mm__mdt> ius = Inactive_Users_Setting_mm__mdt.getAll().values();
        Integer batchSize = 200;
        if (ius.size() > 0 && ius[0].Batch_Size_mm__c > 0) {
            batchSize = ius[0].Batch_Size_mm__c.intValue();
        }

        UserInactivationBatch_mm b = new UserInactivationBatch_mm();
        database.executebatch(b, batchSize);
     }
}

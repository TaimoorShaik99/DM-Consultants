public class LeadReassignmentScheduler implements Schedulable {
    
    // Cron expression to run every 5 minutes using the / syntax
    public static final String CRON_EVERY_5_MIN = '0 */5 * * * ?';
    
    public void execute(SchedulableContext sc) {
        // Only run batch if current time is within any business hours
        if (BusinessHoursUtility.isWithinAnyBusinessHours()) {
            Database.executeBatch(new LeadReassignmentBatch(), 200);
        }
    }
    
    /**
     * Schedule this job to run every 5 minutes
     * @return The scheduled job ID
     */
    public static String scheduleEvery5Minutes() {
        return System.schedule('Lead Reassignment - Every 5 Min', CRON_EVERY_5_MIN, new LeadReassignmentScheduler());
    }
}
public class LeadStatusHandler {

    // Static constants for lead statuses
    private static final String DNQ_STATUS = 'DNQ';
    private static final String NEW_STATUS = 'New';
    private static final String CLOSED_LOST_STATUS = 'Closed Lost';

    // Handles DNQ lead reassignment logic
    public static void handleLeadStatusUpdate(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        System.debug('Entered Lead Status Handler');

        // Collect leads to be reassigned or moved to Closed Lost
        List<Lead> leadsToReassign = new List<Lead>();
        List<Lead> leadsToClose = new List<Lead>();

        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap.get(newLead.Id);

            // Check if the Lead Status has changed to "DNQ"
            if (newLead.Status == DNQ_STATUS && oldLead.Status != DNQ_STATUS) {
                
                // Ensure DNQ_Reason__c is populated
                if (String.isBlank(newLead.DNQ_Reason__c)) {
                    throw new CustomException('DNQ Reason is mandatory when status is set to DNQ.');
                }
            }

            // Check reassignment conditions for "DNQ"
            if (newLead.Status == DNQ_STATUS &&
                newLead.Lead_Status_Timestamp__c != null &&
                newLead.DNQ_Count__c != null &&
                newLead.DNQ_Count__c >= 1 && newLead.DNQ_Count__c <= 3 &&
                Datetime.now().getTime() - newLead.Lead_Status_Timestamp__c.getTime() >= 8 * 60 * 60 * 1000) { // 8 business hours
                
                // Add to reassignment list
                leadsToReassign.add(newLead);
            }

            // Move to "Closed Lost" if DNQ_Count__c exceeds 3
            if (newLead.Status == DNQ_STATUS && newLead.DNQ_Count__c > 3) {
                newLead.Status = CLOSED_LOST_STATUS;
                leadsToClose.add(newLead);
            }
        }

        // Reassign leads to "New" status
        if (!leadsToReassign.isEmpty()) {
            // Use LeadAssignmentHandler to reassign leads
            LeadAssignmentHandler.assignLeadsToCityUsers(leadsToReassign, NEW_STATUS);

            // Update the reassigned leads in the database
            update leadsToReassign;
            System.debug('Reassigned DNQ leads to New status.');
        }

        // Update leads moved to "Closed Lost"
        if (!leadsToClose.isEmpty()) {
            update leadsToClose;
            System.debug('Moved DNQ leads to Closed Lost.');
        }
    }

    // Custom exception for validation errors
    public class CustomException extends Exception {}
}
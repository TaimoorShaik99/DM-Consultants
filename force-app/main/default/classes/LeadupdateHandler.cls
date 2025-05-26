public class LeadupdateHandler {
    
    // Static constant for the lead status that triggers reassignment
    private static final String NOT_ANSWERED_STATUS = 'Not Answered';
    
    // Static constant for the profile name of users who should receive leads
    private static final String COUNSELLOR_PROFILE = 'Counsellor';
    
    // Handles lead reassignment logic when status changes to "Not Answered"
    public static void handleLeadReassignment(List<Lead> newLeads, Map<Id, Lead> oldLeadMap) {
        System.debug('Entered handler');
        
        // Collect leads that need to be reassigned
        List<Lead> leadsToReassign = new List<Lead>();
        
        // Identify leads that changed to "Not Answered" status
        for (Lead newLead : newLeads) {
            Lead oldLead = oldLeadMap.get(newLead.Id);
            
            // Check if the Lead Status has changed to "Not Answered" 
            if (newLead.Status == NOT_ANSWERED_STATUS && 
                oldLead.Status != NOT_ANSWERED_STATUS) {
                
                // Set the Not_Answered_Timestamp__c if not already set
                if (newLead.Not_Answered_Timestamp__c == null) {
                    newLead.Not_Answered_Timestamp__c = Datetime.now();
                }
            }
            
            // Check reassignment conditions
            if (newLead.Status == NOT_ANSWERED_STATUS &&
                newLead.Call_back_Attempts__c == 3 &&
                newLead.WhatsApp_Number__c == true &&
                newLead.Not_Answered_Count__c < 2 &&
                newLead.Not_Answered_Timestamp__c != null &&
                Datetime.now().getTime() - newLead.Not_Answered_Timestamp__c.getTime() >= 16 * 60 * 60 * 1000) { // 16 business hours
                
                // Add to reassignment list
                leadsToReassign.add(newLead);
            }
        }
        
        // Reassign leads to other counselors
        if (!leadsToReassign.isEmpty()) {
            LeadAssignmentHandler.assignLeadsToCityUsers(leadsToReassign, 'as New');
            
            // Increment the Not_Answered_Count__c field for reassigned leads
            for (Lead lead : leadsToReassign) {
                lead.Not_Answered_Count__c = (lead.Not_Answered_Count__c == null) ? 1 : lead.Not_Answered_Count__c + 1;
            }
            
            // Update the leads in the database
            update leadsToReassign;
        }
    }
}
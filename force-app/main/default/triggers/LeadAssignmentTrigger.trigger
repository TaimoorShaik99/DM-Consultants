trigger LeadAssignmentTrigger on Lead (before insert,before update) {
    if(Trigger.isBefore && Trigger.isInsert) {
        system.debug('Triggered');
        LeadAssignmentHandler.assignLeads(Trigger.new);
    }
    
    if(Trigger.isUpdate && Trigger.isBefore) {
        system.debug('Triggered');
        LeadupdateHandler.handleLeadReassignment(Trigger.new, Trigger.oldMap);
        system.debug('Triggered');
    }
}
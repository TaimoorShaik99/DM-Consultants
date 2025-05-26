/*
***NOTES:

*/
public class LeadReassignmentBatch implements Database.Batchable<sObject>, Database.Stateful {
    
    private Integer effectiveHoursThreshold;
    private List<Lead> leadsToReassign;
    private static final String METADATA_NAME = 'Untouched_Leads_6_hrs';
    private String DynamicQuery;
    private String reassignmentType;
    private String calculationType;

    /**
     * @param effectiveHoursThreshold Hours threshold for reassignment
     * @param query Custom query for lead selection
     * @param reassignmentType Type of leads to reassign (New, AttemptingContact, NotAnswered, etc)
     * @param calculationType Type of hours calculation (BusinessHours or CalendarHours)
     */
    public LeadReassignmentBatch(
        Integer effectiveHoursThreshold,
        String query,
        String reassignmentType,
        String calculationType
    ) {
        System.debug(LoggingLevel.INFO, 'Constructor called with threshold: ' + effectiveHoursThreshold + ', query: ' + query + ', reassignmentType: ' + reassignmentType + ', calculationType: ' + calculationType);
        if (effectiveHoursThreshold == null) {
            this.effectiveHoursThreshold = getHoursThresholdFromMetadata();
            System.debug(LoggingLevel.INFO, 'Threshold from metadata: ' + this.effectiveHoursThreshold);
        } else {
            this.effectiveHoursThreshold = effectiveHoursThreshold;
        }
        this.DynamicQuery = query;
        this.leadsToReassign = new List<Lead>();
        this.reassignmentType = String.isBlank(reassignmentType) ? 'New' : reassignmentType;
        this.calculationType = String.isBlank(calculationType) ? 'BusinessHours' : calculationType;
    }

    private static Integer getHoursThresholdFromMetadata() {
        System.debug(LoggingLevel.INFO, 'Fetching threshold from custom metadata...');
        List<Scheduler_Interval__mdt> settings = [
            SELECT Id, MasterLabel, Interval__c 
            FROM Scheduler_Interval__mdt 
            WHERE MasterLabel = :METADATA_NAME
            LIMIT 1
        ];
        if (!settings.isEmpty() && settings[0].Interval__c != null) {
            System.debug(LoggingLevel.INFO, 'Found threshold in metadata: ' + settings[0].Interval__c);
            return Integer.valueOf(settings[0].Interval__c);
        }
        System.debug(LoggingLevel.WARN, 'Threshold not found in metadata, using default 6');
        return 6;
    }
   
    public Database.QueryLocator start(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'Start method called. DynamicQuery: ' + DynamicQuery);
        if (String.isNotBlank(DynamicQuery)) {
            System.debug(LoggingLevel.INFO, 'Using dynamic query for batch.');
            return Database.getQueryLocator(DynamicQuery);
        }
        System.debug(LoggingLevel.INFO, 'Using default query for batch.');
        return Database.getQueryLocator([
            SELECT Id, OwnerId, Country, Assigned_Date__c 
            FROM Lead 
            WHERE IsConverted = false 
            AND Assigned_Date__c != null            
        ]);
    }
    
    public void execute(Database.BatchableContext bc, List<sObject> scope) {
        System.debug(LoggingLevel.INFO, 'Execute method called. Scope size: ' + scope.size());
        List<Lead> leadsToCheck = (List<Lead>) scope;
        for (Lead lead : leadsToCheck) {
            if (lead.Assigned_Date__c == null) {
                continue;
            }
            
            BusinessHours bh = BusinessHoursUtility.getBusinessHoursForCountry(lead.Country);
            DateTime currentTimeInBHTimeZone = BusinessHoursUtility.getCurrentTimeInTimeZone(bh.TimeZoneSidKey);
            
            DateTime startTime = reassignmentType == 'Prospect' 
                ? lead.LastModifiedDate 
                : lead.Assigned_Date__c;
            
            Double effectiveHours = BusinessHoursUtility.calculateEffectiveHours(
                startTime,
                currentTimeInBHTimeZone,
                bh,
                calculationType
            );
            system.debug(LoggingLevel.INFO, 'Effective hours for Lead ' + lead.Name + 'assigned on '+ startTime+'Current Time is '+currentTimeInBHTimeZone + effectiveHours);

            if (shouldReassignLead(lead, effectiveHours)) {
                leadsToReassign.add(lead);
                System.debug(LoggingLevel.INFO, 'Lead marked for reassignment: ' + lead.Id + ' ' + lead.Name);
            }
        }
        System.debug(LoggingLevel.INFO, 'Batch execution complete. Leads marked for reassignment in this batch: ' + leadsToReassign.size());
    }

    private Boolean shouldReassignLead(Lead lead, Double effectiveHours) {
        if (effectiveHours < effectiveHoursThreshold || lead.Owner?.Profile?.Name != 'Counsellor') {
            return false;
        }
        
        switch on reassignmentType {
            when 'New' {
                return lead.Status == 'New';
            }
            when 'AttemptingContact' {
                return lead.Status == 'Attempting Contact' 
                    && lead.Call_back_Attempts__c != null 
                    && lead.Call_back_Attempts__c < 3;
            }
            when 'NotAnswered' {
                return lead.Status == 'Not Answered' 
                    && lead.Call_back_Attempts__c != null 
                    && lead.Call_back_Attempts__c == 3 
                    && lead.Whatsapp__c == true;
            }
            when 'NotInterested' {
                return lead.Status == 'Not Interested' 
                    && lead.Not_Interested_Reason__c != 'Not Enquired';
            }
            when 'Follow-up' {
                return lead.Status == 'Follow-up';
            }
            when 'DNQ' {
                return lead.Status == 'DNQ (Does Not Qualify)';
            }
            when 'Prospect' {
                return lead.Status == 'Prospect' 
                    && lead.Prospect_Status__c == 'P1';
            }
            when else {
                return false;
            }
        }
    }
    
    public void finish(Database.BatchableContext BC) {
        System.debug(LoggingLevel.INFO, 'Finish method called. Leads to reassign: ' + leadsToReassign.size());
        if (!leadsToReassign.isEmpty()) {
            for (Lead lead : leadsToReassign) {
                BusinessHours bh = BusinessHoursUtility.getBusinessHoursForCountry(lead.Country);
                lead.Assigned_Date__c = BusinessHoursUtility.getCurrentTimeInTimeZone(bh.TimeZoneSidKey);
                System.debug(LoggingLevel.INFO, 'Assigned_Date__c updated for Lead: ' + lead.Id + ' to ' + lead.Assigned_Date__c);
            }
            LeadAssignmentHandler.assignAndUpdateLeads(leadsToReassign);
            System.debug(LoggingLevel.INFO, 'Reassigned ' + leadsToReassign.size() + ' leads');
        } else {
            System.debug(LoggingLevel.INFO, 'No leads needed reassignment');
        }
    }
}
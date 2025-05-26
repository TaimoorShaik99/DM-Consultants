/**
 * Controller for the recordOwnerTransfer LWC
 * Handles transferring ownership of Lead and Opportunity records
 */
public with sharing class RecordOwnerTransferController {
    
    /**
     * Wrapper class to hold record details for the data table
     */
    public class RecordWrapper {
        @AuraEnabled public String recordId;
        @AuraEnabled public String recordName;
        @AuraEnabled public String objectType;
        @AuraEnabled public String currentStage;
        @AuraEnabled public String newStage;
        @AuraEnabled public String currentOwnerName;
        @AuraEnabled public String newOwnerName;
        
        public RecordWrapper(String recordId, String recordName, String objectType, 
                             String currentStage, String newStage, 
                             String currentOwnerName, String newOwnerName) {
            this.recordId = recordId;
            this.recordName = recordName;
            this.objectType = objectType;
            this.currentStage = currentStage;
            this.newStage = newStage;
            this.currentOwnerName = currentOwnerName;
            this.newOwnerName = newOwnerName;
        }
    }
    
    /**
     * Get active users that can be assigned as owners
     * @return List of eligible users
     */
    @AuraEnabled(cacheable=true)
    public static List<User> getUsers() {
        try {
            return [
                SELECT Id, Name 
                FROM User 
                WHERE IsActive = true 
                ORDER BY Name
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving users: ' + e.getMessage());
        }
    }
    
    /**
     * Get details for a single record
     * @param recordId ID of the record
     * @param objectApiName API name of the object (Lead or Opportunity)
     * @return Map with record details
     */
    
    public static string getRecordDetails(String recordId) {
        try {
           
            string objectApiName;
            if (String.isBlank(recordId)) {
                throw new AuraHandledException('Record ID is required');
            }
            
           
          else {
                Id recordIdTyped = Id.valueOf(recordId);
                Schema.SObjectType objectType = recordIdTyped.getSObjectType();
                objectApiName = objectType.getDescribe().getName();
          }
           return objectApiName;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving record details: ' + e.getMessage());
        }
    }
    
    /**
     * Get preview data for records that will be transferred
     * @param recordIds List of record IDs
     * @param newOwnerId ID of the new owner
     * @param transferType Type of transfer ('asIs' or 'asNew')
     * @return List of record wrappers with details
     */
    @AuraEnabled
    public static List<RecordWrapper> getRecordPreview(
        List<String> recordIds,
        String newOwnerId,
        String transferType
    ) {
        List<RecordWrapper> wrappers = new List<RecordWrapper>();
        
        try {
            if (recordIds == null || recordIds.isEmpty()) {
                throw new AuraHandledException('No record IDs provided');
            }
            
            if (String.isBlank(newOwnerId)) {
                throw new AuraHandledException('New Owner ID is required');
            }
            
            // Get new owner name
            User newOwner = [SELECT Name FROM User WHERE Id = :newOwnerId LIMIT 1];
            String newOwnerName = newOwner.Name;
            
            // Determine object type from first ID
            Id sampleId = Id.valueOf(recordIds[0]);
            Schema.SObjectType sObjectType = sampleId.getSObjectType();
            String objectApiName = sObjectType.getDescribe().getName();
            
            // Create set of IDs
            Set<Id> idSet = new Set<Id>();
            for (String idStr : recordIds) {
                idSet.add(Id.valueOf(idStr));
            }
            
            // Process Lead records
            if (objectApiName == 'Lead') {
                for (Lead lead : [
                    SELECT Id, Name, Status, OwnerId, Owner.Name 
                    FROM Lead 
                    WHERE Id IN :idSet
                ]) {
                    String newStatus = transferType == 'asNew' ? 'New' : lead.Status;
                    
                    wrappers.add(new RecordWrapper(
                        lead.Id,
                        lead.Name,
                        'Lead',
                        lead.Status,
                        newStatus,
                        lead.Owner.Name,
                        newOwnerName
                    ));
                }
            }
            // Process Opportunity records
            else if (objectApiName == 'Opportunity') {
                for (Opportunity opp : [
                    SELECT Id, Name, StageName, OwnerId, Owner.Name 
                    FROM Opportunity 
                    WHERE Id IN :idSet
                ]) {
                    String newStage = transferType == 'asNew' ? 'Prospecting' : opp.StageName;
                    
                    wrappers.add(new RecordWrapper(
                        opp.Id,
                        opp.Name,
                        'Opportunity',
                        opp.StageName,
                        newStage,
                        opp.Owner.Name,
                        newOwnerName
                    ));
                }
            } else {
                throw new AuraHandledException('Unsupported object type: ' + objectApiName);
            }
            
            return wrappers;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error preparing record preview: ' + e.getMessage());
        }
    }
    
    /**
     * Transfer ownership - works for both single and bulk operations 
     * @param recordId Single record ID (for backwards compatibility)
     * @param recordIds List of record IDs (for bulk operations)
     * @param newOwnerId ID of the new owner
     * @param objectApiName API name of the object (optional, detected from recordIds)
     * @param transferType Type of transfer ('asIs' or 'asNew')
     * @return Results of the transfer operation
     */
    @AuraEnabled
    public static Map<String, Object> transferOwnership(
        List<String> recordIds,
        String newOwnerId,
        String objectApiName,
        String transferType
    ) {
        // Initialize result map
        Map<String, Object> result = new Map<String, Object>{
            'success' => false,
            'objectLabel' => '',
            'successCount' => 0,
            'errorMessage' => '',
            'errors' => new List<Map<String, Object>>(),
            'updatedRecords' => new List<RecordWrapper>()
        };
        
        try {
            // Handle both single recordId and recordIds list     
            if (recordIds == null || recordIds.isEmpty()) {
                throw new AuraHandledException('No record IDs provided');
            }
            
            if (String.isBlank(newOwnerId)) {
                throw new AuraHandledException('New Owner ID is required');
            }
            
            // Determine object type if not provided
            Id sampleId = Id.valueOf(recordIds[0]);
            Schema.SObjectType sObjectType = sampleId.getSObjectType();
            objectApiName = sObjectType.getDescribe().getName();
            
            // Get new owner name for wrapper
            User newOwner = [SELECT Name FROM User WHERE Id = :newOwnerId LIMIT 1];
            String newOwnerName = newOwner.Name;
            
            // Set object label for UI
            String objectLabel = Schema.getGlobalDescribe().get(objectApiName).getDescribe().getLabel();
            result.put('objectLabel', recordIds.size() == 1 ? objectLabel : objectLabel + 's');
            
            // Convert string IDs to Id set
            Set<Id> idSet = new Set<Id>();
            for (String idStr : recordIds) {
                idSet.add(Id.valueOf(idStr));
            }
            
            // Process Lead records
            if (objectApiName == 'Lead') {
                List<Lead> leadsToUpdate = new List<Lead>();
                Map<Id, String> leadNames = new Map<Id, String>();
                List<RecordWrapper> updatedLeads = new List<RecordWrapper>();
                
                for (Lead lead : [SELECT Id, Name, Status, OwnerId, Owner.Name FROM Lead WHERE Id IN :idSet]) {
                    leadNames.put(lead.Id, lead.Name);
                    String newStatus = lead.Status;
                    
                    // Only update if the owner is changing
                    if (lead.OwnerId != newOwnerId) {
                        // Handle transfer type
                        if (transferType == 'asNew') {
                            newStatus = 'New';
                            lead.Status = newStatus;
                        }
                        lead.OwnerId = newOwnerId;
                        leadsToUpdate.add(lead);
                        
                        // Add to updated records wrapper
                        updatedLeads.add(new RecordWrapper(
                            lead.Id,
                            lead.Name,
                            'Lead',
                            lead.Status,
                            newStatus,
                            lead.Owner.Name,
                            newOwnerName
                        ));
                    } else {
                        // Owner already set - count as success
                        result.put('successCount', (Integer)result.get('successCount') + 1);
                        
                        // Still add to updated records wrapper
                        updatedLeads.add(new RecordWrapper(
                            lead.Id,
                            lead.Name,
                            'Lead',
                            lead.Status,
                            lead.Status,
                            lead.Owner.Name,
                            lead.Owner.Name
                        ));
                    }
                }
                
                // Add updated records to result
                result.put('updatedRecords', updatedLeads);
                
                if (!leadsToUpdate.isEmpty()) {
                    List<Database.SaveResult> saveResults = Database.update(leadsToUpdate, false);  
                    for (Integer i = 0; i < saveResults.size(); i++) {
                        Database.SaveResult sr = saveResults[i];
                        Lead lead = leadsToUpdate[i];
                        
                        if (sr.isSuccess()) {
                            // Increment success counter
                            result.put('successCount', (Integer)result.get('successCount') + 1);
                        } else {
                            // Add error information
                            String errorMessage = '';
                            for (Database.Error err : sr.getErrors()) {
                                errorMessage += err.getMessage() + ' ';
                            }
                            
                            String formattedError = 'Error in ' + leadNames.get(lead.Id) + ': ' + errorMessage.trim();
                            
                            List<Map<String, Object>> errors = (List<Map<String, Object>>)result.get('errors');
                            errors.add(new Map<String, Object>{
                                'recordId' => lead.Id,
                                'recordName' => leadNames.get(lead.Id),
                                'message' => formattedError
                            });
                            
                            // For single record, also set the main error message
                            if (recordIds.size() == 1) {
                                result.put('errorMessage', formattedError);
                            }
                        }
                    }
                }
            }
            // Process Opportunity records
            else if (objectApiName == 'Opportunity') {
                List<Opportunity> oppsToUpdate = new List<Opportunity>();
                Map<Id, String> oppNames = new Map<Id, String>();
                List<RecordWrapper> updatedOpps = new List<RecordWrapper>();
                
                for (Opportunity opp : [SELECT Id, Name, StageName, OwnerId, Owner.Name FROM Opportunity WHERE Id IN :idSet]) {
                    oppNames.put(opp.Id, opp.Name);
                    String newStage = opp.StageName;
                    
                    // Only update if the owner is changing
                    if (opp.OwnerId != newOwnerId) {
                        // Handle transfer type
                        if (transferType == 'asNew') {
                            newStage = 'Prospecting';
                            opp.StageName = newStage;
                        }
                        
                        opp.OwnerId = newOwnerId;
                        oppsToUpdate.add(opp);
                        
                        // Add to updated records wrapper
                        updatedOpps.add(new RecordWrapper(
                            opp.Id,
                            opp.Name,
                            'Opportunity',
                            opp.StageName,
                            newStage,
                            opp.Owner.Name,
                            newOwnerName
                        ));
                    } else {
                        // Owner already set - count as success
                        result.put('successCount', (Integer)result.get('successCount') + 1);
                        
                        // Still add to updated records wrapper
                        updatedOpps.add(new RecordWrapper(
                            opp.Id,
                            opp.Name,
                            'Opportunity',
                            opp.StageName,
                            opp.StageName,
                            opp.Owner.Name,
                            opp.Owner.Name
                        ));
                    }
                }
                
                // Add updated records to result
                result.put('updatedRecords', updatedOpps);
                
                if (!oppsToUpdate.isEmpty()) {
                    List<Database.SaveResult> saveResults = Database.update(oppsToUpdate, false);
                    
                    for (Integer i = 0; i < saveResults.size(); i++) {
                        Database.SaveResult sr = saveResults[i];
                        Opportunity opp = oppsToUpdate[i];
                        
                        if (sr.isSuccess()) {
                            // Increment success counter
                            result.put('successCount', (Integer)result.get('successCount') + 1);
                        } else {
                            // Add error information
                            String errorMessage = '';
                            for (Database.Error err : sr.getErrors()) {
                                errorMessage += err.getMessage() + ' ';
                            }
                            
                            String formattedError = 'Error in ' + oppNames.get(opp.Id) + ': ' + errorMessage.trim();
                            
                            List<Map<String, Object>> errors = (List<Map<String, Object>>)result.get('errors');
                            errors.add(new Map<String, Object>{
                                'recordId' => opp.Id,
                                'recordName' => oppNames.get(opp.Id),
                                'message' => formattedError
                            });
                            
                            // For single record, also set the main error message
                            if (recordIds.size() == 1) {
                                result.put('errorMessage', formattedError);
                            }
                        }
                    }
                }
            } else {
                throw new AuraHandledException('Unsupported object type: ' + objectApiName);
            }
            
            // Set success flag based on if any records were successfully transferred
            Integer successCount = (Integer)result.get('successCount');
            result.put('success', successCount > 0);
            
            // Set error message for bulk operations
            if (recordIds.size() > 1 && successCount < recordIds.size()) {
                result.put('errorMessage', 'Some records could not be transferred. See details for more information.');
            }
            
            return result;
        } catch (Exception e) {
            // Return error
            result.put('success', false);
            result.put('errorMessage', 'Error: ' + e.getMessage());
            
            List<Map<String, Object>> errors = (List<Map<String, Object>>)result.get('errors');
            errors.add(new Map<String, Object>{
                'recordId' => 'general',
                'recordName' => 'General Error',
                'message' => e.getMessage()
            });
            
            return result;
        }
    }
}
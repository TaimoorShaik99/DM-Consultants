/**
 * Simple REST API endpoint to create leads from a web form
 * Uses strongly typed request wrapper for data handling with retry mechanism
 */
@RestResource(urlMapping='/WebToLeads')
global without sharing class LeadsFromExternalSource {
    
    // Maximum number of retry attempts
    private static final Integer MAX_RETRIES = 3;
    
    /**
     * Request wrapper class to properly deserialize incoming JSON
     */
    global class LeadRequest {
      
    public String lastName;
    public String email;
    public String phone;
    public string UTMCampaign;
    public String AgeRange;                     // Maps to Age__c
    public String ImmigrationType;              // Maps to Lead_Type__c
    public String PrefferedLocation;            // Maps to Branch__c
    public String Education;                    // Maps to HighestLevelOfEducation__c
    public String DestinationCountry;
    public String ResidentCountry;
     
        
      /*  // Validate required fields
        public void validate() {
            List<String> errors = new List<String>();
            
            if (String.isBlank(lastName)) {
                errors.add('Last Name is required');
            }
            
            if (String.isBlank(email)) {
                errors.add('Email is required');
            }
            
            if (String.isBlank(phone)) {
                errors.add('Phone is required');
            }
            
            if (!errors.isEmpty()) {
                throw new CustomException(String.join(errors, ', '));
            }
        }*/
    }
    
    /**
     * Response class
     */
    global class LeadResponse {
        public Boolean success;
        public String leadId;
        public String message;
    }
    
    /**
     * Creates a lead from web form data
     * POST endpoint accessible at /services/apexrest/WebToLeads
     */
    @HttpPost
    global static LeadResponse createLead() {
        LeadResponse response = new LeadResponse();
        response.success = false;
        
        try {
            // Get and parse the request body using our custom wrapper
            RestRequest req = RestContext.request;
            String requestBody = req.requestBody.toString();
            LeadRequest leadRequest = (LeadRequest)JSON.deserialize(requestBody, LeadRequest.class);

            // Debug log for the entire deserialized request object
            System.debug(LoggingLevel.INFO, 'Deserialized LeadRequest: ' + JSON.serializePretty(leadRequest));
            
            // Look for duplicate leads
            List<Lead> duplicateLeads = [
                SELECT Id, Name, Re_Enquiry__c, Re_Enquiry_Counter__c,isconverted
                FROM Lead 
                WHERE isConverted = false 
                AND Email = :leadRequest.email
                AND Phone = :leadRequest.phone
                AND CreatedDate>=LAST_N_DAYS:7
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            system.debug('Duplicate Leads are'+duplicateLeads);
            system.debug('req email'+leadRequest.email);
            system.debug('req phn'+leadRequest.Phone);
            
            Id leadId;
            
            // Process based on whether duplicate exists
            if (duplicateLeads.isEmpty()) {
                // No duplicate found - create new lead
                leadId = createLeadWithRetry(leadRequest);
            } else {
                // Duplicate found - update the existing lead
                Lead duplicateLead = duplicateLeads[0];
                
                // Increment re-enquiry counter
                duplicateLead.Re_Enquiry_Counter__c = (duplicateLead.Re_Enquiry_Counter__c != null) ? 
                    duplicateLead.Re_Enquiry_Counter__c + 1 : 1;
                
                // Set Re_Enquiry flag to true
                duplicateLead.Re_Enquiry__c = true;
                
                
                // Update the lead
                update duplicateLead;
                
                // Use the duplicate lead's ID
                leadId = duplicateLead.Id;
            }
            
            // Set success response
            response.success = true;
            response.leadId = leadId;
            response.message = 'Lead processed successfully';
            
        } catch (Exception e) {
            // Handle errors
            response.success = false;
            response.message = 'Error: ' + e.getMessage();
            System.debug('Error processing lead: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
        
        return response;
    }
    
    /**
     * Creates a lead with retry mechanism
     */
    private static Id createLeadWithRetry(LeadRequest request) {
        Integer attempts = 0;
        Exception lastException;
        
        while (attempts < MAX_RETRIES) {
            try {
                // Create the lead
                Lead newLead = new Lead();
                
                // Set the lead fields from request
                updateLeadFromRequest(newLead, request);
                
                // Insert the lead
                insert newLead;
                return newLead.Id;
                
            } catch (DmlException e) {
                lastException = e;
                
                // Only retry for specific errors that might be transient
                if (isRetryableError(e)) {
                    attempts++;
                    if (attempts < MAX_RETRIES) {
                        // Wait before retrying
                        sleep(1000 * attempts); // Exponential backoff
                        continue;
                    }
                }
                
                // For non-retryable errors, throw immediately
                throw e;
            } catch (Exception e) {
                // For other exceptions, don't retry
                throw e;
            }
        }
        
        // If we reach here, we've failed after all retries
        throw lastException;
    }
    
    /**
     * Update a lead with data from the request
     */
    private static void updateLeadFromRequest(Lead lead, LeadRequest request) {
        // Set standard fields
             
        lead.LastName = request.lastName;
        lead.Email = request.email;
        lead.Phone = request.phone;
        lead.Age__c= request.AgeRange;
        lead.Lead_Type__c = request.ImmigrationType;
        lead.Branch__c = request.PrefferedLocation;
        lead.HighestLevelOfEducation__c=request.Education;
        lead.Destination_Country__c=request.DestinationCountry;
        lead.Resident_Country__c=request.ResidentCountry;
        lead.UTM_Campaign__c=request.UTMCampaign;
        lead.LeadSource =  'Web';
 
    }
    
    /**
     * Determines if an error is retryable
     */
    private static Boolean isRetryableError(Exception e) {
        String errorMsg = e.getMessage().toLowerCase();
        
        // Examples of transient errors to retry
        return errorMsg.contains('unable to obtain lock') ||
               errorMsg.contains('unable_to_lock_row') ||
               errorMsg.contains('lock') ||
               errorMsg.contains('unable to obtain exclusive access') ||
               errorMsg.contains('system.limitexception') ||
               errorMsg.contains('service unavailable');
    }
    
    
    /**
     * Simple sleep function
     */
    private static void sleep(Integer milliseconds) {
        Long startTime = System.currentTimeMillis();
        while (System.currentTimeMillis() - startTime < milliseconds) {
            // Sleep
        }
    }
    
    /**
     * Custom exception class
     */
    public class CustomException extends Exception {}
}
public class AgreementPDFController {
    
    // Current variables
    public String pageFooter { get; set; }
    public String headerText { get; set; }
    public String termsAndConditions { get; set; }
    public String Preamble { get; set; }
    public String purpose { get; set; }
        public String arabicFontBase64 { get; set; }


    // Additional variables needed based on the query
    public String definitionsAndInterpretation { get; set; }
    public String definitionsAndInterpretationTrans { get; set; }
    public String purposeTranslation { get; set; }
    public String responsibilitiesOfDMConsultants { get; set; }
    public String responsibilitiesOfDMConsultantsTrans { get; set; }
    public String responsibilitiesOfDMConsultants2 { get; set; }
    public String x131072 { get; set; }
    public String responsibilitesClient { get; set; }
    public String responsibilitesClientTrans { get; set; }
    public String feesAndPaymentTerms { get; set; }
    public String feesAndPaymentTermsTrans { get; set; }
    public String confidentiality { get; set; }
    public String confidentialityTrans { get; set; }
    public String termination { get; set; }
    public String terminationTranslation { get; set; }
    public String forceMajeure { get; set; }
    public String forceMajeureTrans { get; set; }
    public String governingLaw { get; set; }
    public String governingLawTrans { get; set; }
    public String entireAgreement { get; set; }
    public String entireAgreementTrans { get; set; }
    public String limitationOfLiability { get; set; }
    public String limitationOfLiabilityTranslation { get; set; }
    public String retentionAndReturnOfDocuments { get; set; }
    public String retentionAndReturnOfDocumentsTrans { get; set; }
    public String annexure { get; set; }
    public String annexureTranslation { get; set; }
    public String execution { get; set; }
    public String executionTranslation { get; set; }
    public String appointmentAndMandate { get; set; }
    public String appointmentAndMandateTrans { get; set; }
    public String scopeOfServices { get; set; }
    public String scopeOfServicesTrans { get; set; }
    public String clientObligation { get; set; }
    public String clientObligationTrans { get; set; }
    public String englishFrenchProficiencyTests { get; set; }
    public String englishFrenchProficiencyTestsTrans { get; set; }
    public String englishFrenchProficiencyContinue { get; set; }
    public String englishFrenchProficiencyContinueTran { get; set; }
    public String exclusions { get; set; }
    public String exclusionsTranslation { get; set; }
    public String refundPolicy { get; set; }
    public String refundPolicyTranslation { get; set; }
    public String refundPolicyContinue { get; set; }
    public String refundPolicyContinueTrans { get; set; }
    public String refundProceduresAndConditions { get; set; }
    public String refundProceduresAndConditionsTrans { get; set; }
    public String refundProceduresAndConditionsContinue { get; set; }
    public String refundProceduresAndConditionsConTra { get; set; }
    public String durationAndRenewal { get; set; }
    public String durationAndRenewalTranslation { get; set; }
    public String acknowledgment { get; set; }
    public String acknowledgmentTranslation { get; set; }
    public String paymentTermsAndPaymentMethod { get; set; }
    public String paymentTermsAndPaymentMethodTrans { get; set; }
    public String country { get; set; }
    public String address { get; set; }
    public String paymentTerms2 { get; set; }
    
    // Opportunity-specific variables for the view
    public String opportunityId { get; set; }
    public String clientName { get; set; }
    public String clientAddress { get; set; }
    public String clientCity { get; set; }
    public String clientPhone { get; set; }
    public String clientEmail { get; set; }
    public String programInterested { get; set; }
    public String countryInterested { get; set; }
    public String opportunityNumber { get; set; }
    public String opportunityAmount { get; set; }
    public String todayDate { get; set; }
    public string footer{ get; set; }
    public string FooterTerms{ get; set; }
    
    // Constructor for StandardController extension
    public AgreementPDFController(ApexPages.StandardController stdController) {
        // Get the opportunity ID from standard controller
        Opportunity opp = (Opportunity)stdController.getRecord();
        
        // Initialize todayDate
        todayDate = System.today().format();
        
        // Load agreement template
        initializeAgreementData();
        
        // If opp.Id is available (not a new record), load the full opportunity
        if (opp != null && opp.Id != null) {
            loadOpportunityData(opp.Id);
        }
    }
    
    // Default constructor
    public AgreementPDFController() {
        // Today's date for the agreement
        todayDate = System.today().format();
         StaticResource arabicFont = [SELECT Body FROM StaticResource WHERE Name = 'ArabicFont'];
        Blob fontBlob = arabicFont.Body;
        arabicFontBase64 = EncodingUtil.base64Encode(fontBlob);

        // Initialize agreement data
        initializeAgreementData();
    }
    
    // Set the Opportunity ID from the page parameter
    public void setOpportunityId(String oppId) {
        this.opportunityId = oppId;
        if (String.isNotBlank(oppId)) {
            loadOpportunityData(Id.valueOf(oppId));
        }
    }
    
    // Load Opportunity data with ID parameter
    private void loadOpportunityData(Id oppId) {
        if (oppId != null) {
            try {
                        Opportunity opp = [
                    SELECT Id, Name, Amount, CloseDate, StageName, AccountId,
                           Account.Name, Account.BillingStreet, Account.BillingCity, 
                           Account.BillingState, Account.BillingPostalCode, Account.BillingCountry,
                           Account.Phone, Account.PersonEmail, Program__c, Country__c
                           
                    FROM Opportunity 
                    WHERE Id = :oppId LIMIT 1
                ];
                
                // Set client information from Opportunity
                clientName = opp.Account.Name;
                clientAddress = formatAddress(opp.Account);
                clientCity = opp.Account.BillingCity;
                clientPhone = opp.Account.Phone;
                clientEmail = opp.Account.PersonEmail;
                programInterested = opp.Program__c;
                countryInterested = opp.Country__c;
                opportunityNumber = opp.Id;
                opportunityAmount = opp.Amount != null ? String.valueOf(opp.Amount) : '';
                
                // Process templates with opportunity data
                processTemplatesWithOpportunityData(opp);
            }
            catch (Exception e) {
                System.debug('Error loading Opportunity data: ' + e.getMessage());
            }
        }
    }
    
    private void initializeAgreementData() {
        try {
            // Get metadata configuration
            Aggreement__mdt config = [
                SELECT Page_Footer__c, Header_Text__c, Terms_And_Conditions__c
                FROM Aggreement__mdt
                WHERE DeveloperName = 'DMM_Application_for_Service'
                LIMIT 1
            ];
            
            // Get the default Agreement template
            Agreement__c agr = [
                SELECT Id, Name, Preamble__c, Definiitons_and_Interpretation__c, 
                       Definiitons_and_Interpretation_Transl__c, Purpose__c, Purpose_Translation__c, 
                       Responsibilities_of_DM_CONSULTANTS__c, Responsibilities_of_DM_CONSULTANTS_Trans__c, 
                       Responsibilities_of_DM_CONSULTANTS_2__c, X131_072__c, 
                       Responsibilites_Client__c, Responsibilites_Client_Trans__c, 
                       Fees_and_Payment_Terms__c, Fees_and_Payment_Terms_Trans__c, 
                       Confidentiality__c, Confidentiality_Trans__c, Termination__c, 
                       Force_Majeure__c, Force_Majeure_Trans__c, Governing_law__c, 
                       Governing_law_Trans__c, Entire_Agreement__c, Entire_Agreement_Trans__c, 
                       Limitation_of_Liability__c, Termination_translation__c, 
                       Limitation_of_Liability_translation__c, Retention_and_Return_of_Documents__c, 
                       Retention_and_Return_of_Documents_trans__c, Annexure__c, 
                       Annexure_translation__c, Execution__c, Execution_translation__c, 
                       Appointment_and_Mandate__c, Appointment_and_Mandate_trans__c, 
                       Scope_of_Services__c, Scope_of_Services_trans__c, Client_Obligation__c, 
                       Client_Obligation_trans__c, English_French_Proficiency_Tests__c, 
                       English_French_Proficiency_Tests_trans__c, English_French_Proficiency_continue__c, 
                       English_French_Proficiency_continue_tran__c, Exclusions__c, 
                       Exclusions_translation__c, Refund_Policy__c, Refund_Policy_translation__c, 
                       Refund_Policy_continue__c, Refund_Policy_continue_trans__c, 
                       Refund_procedures_and_conditions__c, Refund_procedures_and_conditions_trans__c, 
                       Refund_procedures_and_conditions_continu__c, Refund_procedures_and_conditions_con_tra__c, 
                       Duration_and_Renewal__c, Duration_and_Renewal_translation__c, 
                       Acknowledgment__c, Acknowledgment_translation__c, 
                       Payment_Terms_and_Payment_method__c, Payment_Terms_and_Payment_method_trans__c, 
                       Country__c, Terms_and_Conditions__c, Adress__c, Payment_Terms_2__c,Footer__c,Footer_Terms__c
                FROM Agreement__c  
                LIMIT 1
            ];

            // Set basic variables from config
            pageFooter = config.Page_Footer__c;
            headerText = config.Header_Text__c;
            
            // Set variables from Agreement record (without Opportunity data processing)
            termsAndConditions = agr.Terms_and_Conditions__c;
            Preamble = agr.Preamble__c;
            purpose = agr.Purpose__c;
            definitionsAndInterpretation = agr.Definiitons_and_Interpretation__c;
            definitionsAndInterpretationTrans = agr.Definiitons_and_Interpretation_Transl__c;
            purposeTranslation = agr.Purpose_Translation__c;
            responsibilitiesOfDMConsultants = agr.Responsibilities_of_DM_CONSULTANTS__c;
            responsibilitiesOfDMConsultantsTrans = agr.Responsibilities_of_DM_CONSULTANTS_Trans__c;
            responsibilitiesOfDMConsultants2 = agr.Responsibilities_of_DM_CONSULTANTS_2__c;
            x131072 = agr.X131_072__c;
            responsibilitesClient = agr.Responsibilites_Client__c;
            responsibilitesClientTrans = agr.Responsibilites_Client_Trans__c;
            feesAndPaymentTerms = agr.Fees_and_Payment_Terms__c;
            feesAndPaymentTermsTrans = agr.Fees_and_Payment_Terms_Trans__c;
            confidentiality = agr.Confidentiality__c;
            confidentialityTrans = agr.Confidentiality_Trans__c;
            termination = agr.Termination__c;
            terminationTranslation = agr.Termination_translation__c;
            forceMajeure = agr.Force_Majeure__c;
            forceMajeureTrans = agr.Force_Majeure_Trans__c;
            governingLaw = agr.Governing_law__c;
            governingLawTrans = agr.Governing_law_Trans__c;
            entireAgreement = agr.Entire_Agreement__c;
            entireAgreementTrans = agr.Entire_Agreement_Trans__c;
            limitationOfLiability = agr.Limitation_of_Liability__c;
            limitationOfLiabilityTranslation = agr.Limitation_of_Liability_translation__c;
            retentionAndReturnOfDocuments = agr.Retention_and_Return_of_Documents__c;
            retentionAndReturnOfDocumentsTrans = agr.Retention_and_Return_of_Documents_trans__c;
            annexure = agr.Annexure__c;
            annexureTranslation = agr.Annexure_translation__c;
            execution = agr.Execution__c;
            executionTranslation = agr.Execution_translation__c;
            appointmentAndMandate = agr.Appointment_and_Mandate__c;
            appointmentAndMandateTrans = agr.Appointment_and_Mandate_trans__c;
            scopeOfServices = agr.Scope_of_Services__c;
            scopeOfServicesTrans = agr.Scope_of_Services_trans__c;
            clientObligation = agr.Client_Obligation__c;
            clientObligationTrans = agr.Client_Obligation_trans__c;
            englishFrenchProficiencyTests = agr.English_French_Proficiency_Tests__c;
            englishFrenchProficiencyTestsTrans = agr.English_French_Proficiency_Tests_trans__c;
            englishFrenchProficiencyContinue = agr.English_French_Proficiency_continue__c;
            englishFrenchProficiencyContinueTran = agr.English_French_Proficiency_continue_tran__c;
            exclusions = agr.Exclusions__c;
            exclusionsTranslation = agr.Exclusions_translation__c;
            refundPolicy = agr.Refund_Policy__c;
            refundPolicyTranslation = agr.Refund_Policy_translation__c;
            refundPolicyContinue = agr.Refund_Policy_continue__c;
            refundPolicyContinueTrans = agr.Refund_Policy_continue_trans__c;
            refundProceduresAndConditions = agr.Refund_procedures_and_conditions__c;
            refundProceduresAndConditionsTrans = agr.Refund_procedures_and_conditions_trans__c;
            refundProceduresAndConditionsContinue = agr.Refund_procedures_and_conditions_continu__c;
            refundProceduresAndConditionsConTra = agr.Refund_procedures_and_conditions_con_tra__c;
            durationAndRenewal = agr.Duration_and_Renewal__c;
            durationAndRenewalTranslation = agr.Duration_and_Renewal_translation__c;
            acknowledgment = agr.Acknowledgment__c;
            acknowledgmentTranslation = agr.Acknowledgment_translation__c;
            paymentTermsAndPaymentMethod = agr.Payment_Terms_and_Payment_method__c;
            paymentTermsAndPaymentMethodTrans = agr.Payment_Terms_and_Payment_method_trans__c;
            country = agr.Country__c;
            address = agr.Adress__c;
            paymentTerms2 = agr.Payment_Terms_2__c;
            footer=agr.Footer__c;
            FooterTerms=agr.Footer_Terms__c;
        } 
        catch (Exception e) {
            // Fallback or logging
            pageFooter = 'Default footer text';
            headerText = 'Default header text';
            termsAndConditions = 'Default terms';
            Preamble = 'Default preamble';
            System.debug('Error in AgreementPDFController: ' + e.getMessage());
        }
    }
    
    // Process agreement templates with Opportunity data
    private void processTemplatesWithOpportunityData(Opportunity opp) {
        // Only process if we have a valid opportunity
        if (opp == null) return;
        
        // Process each rich text field with opportunity data
        Preamble = processDynamicContent(Preamble, opp);
        definitionsAndInterpretation = processDynamicContent(definitionsAndInterpretation, opp);
        purpose = processDynamicContent(purpose, opp);
        responsibilitiesOfDMConsultants = processDynamicContent(responsibilitiesOfDMConsultants, opp);
        responsibilitesClient = processDynamicContent(responsibilitesClient, opp);
        feesAndPaymentTerms = processDynamicContent(feesAndPaymentTerms, opp);
        confidentiality = processDynamicContent(confidentiality, opp);
        termination = processDynamicContent(termination, opp);
        forceMajeure = processDynamicContent(forceMajeure, opp);
        governingLaw = processDynamicContent(governingLaw, opp);
        entireAgreement = processDynamicContent(entireAgreement, opp);
        limitationOfLiability = processDynamicContent(limitationOfLiability, opp);
        retentionAndReturnOfDocuments = processDynamicContent(retentionAndReturnOfDocuments, opp);
        annexure = processDynamicContent(annexure, opp);
        execution = processDynamicContent(execution, opp);
        appointmentAndMandate = processDynamicContent(appointmentAndMandate, opp);
        scopeOfServices = processDynamicContent(scopeOfServices, opp);
        clientObligation = processDynamicContent(clientObligation, opp);
        englishFrenchProficiencyTests = processDynamicContent(englishFrenchProficiencyTests, opp);
        englishFrenchProficiencyContinue = processDynamicContent(englishFrenchProficiencyContinue, opp);
        exclusions = processDynamicContent(exclusions, opp);
        refundPolicy = processDynamicContent(refundPolicy, opp);
        refundPolicyContinue = processDynamicContent(refundPolicyContinue, opp);
        refundProceduresAndConditions = processDynamicContent(refundProceduresAndConditions, opp);
        refundProceduresAndConditionsContinue = processDynamicContent(refundProceduresAndConditionsContinue, opp);
        durationAndRenewal = processDynamicContent(durationAndRenewal, opp);
        acknowledgment = processDynamicContent(acknowledgment, opp);
        paymentTermsAndPaymentMethod = processDynamicContent(paymentTermsAndPaymentMethod, opp);
        paymentTerms2 = processDynamicContent(paymentTerms2, opp);
    }
    
    // Helper method to process dynamic content by replacing merge fields with Opportunity data
    private String processDynamicContent(String content, Opportunity opp) {
        if (content == null || opp == null) {
            return content;
        }
        
        // Replace merge fields with opportunity data
        Map<String, String> mergeFieldMap = new Map<String, String>();
        
        // Add opportunity fields
        if (opp.Account != null) {
            mergeFieldMap.put('{CLIENT_NAME}', opp.Account.Name);
            mergeFieldMap.put('{CLIENT_ADDRESS}', formatAddress(opp.Account));
            mergeFieldMap.put('{CLIENT_PHONE}', opp.Account.Phone);
            mergeFieldMap.put('{CLIENT_CITY}', opp.Account.BillingCity);
            mergeFieldMap.put('{CLIENT_STATE}', opp.Account.BillingState);
            mergeFieldMap.put('{CLIENT_COUNTRY}', opp.Account.BillingCountry);
        }
        
        mergeFieldMap.put('{CLIENT_EMAIL}', opp.Account.PersonEmail);
        mergeFieldMap.put('{PROGRAM_INTERESTED}', opp.Program__c);
        mergeFieldMap.put('{COUNTRY_INTERESTED}', opp.Country__c);
        mergeFieldMap.put('{AGREEMENT_NUMBER}', opp.Id);
        mergeFieldMap.put('{AMOUNT}', opp.Amount != null ? String.valueOf(opp.Amount) : '');
        mergeFieldMap.put('{TODAY_DATE}', System.today().format());
        mergeFieldMap.put('{OPPORTUNITY_NAME}', opp.Name);
        
        // Replace all merge fields in the content
        for (String key : mergeFieldMap.keySet()) {
            if (mergeFieldMap.get(key) != null) {
                content = content.replace(key, mergeFieldMap.get(key));
            }
        }
        
        return content;
    }
    
    // Overloaded method for when no opportunity is available
    private String processDynamicContent(String content) {
        if (content == null) {
            return content;
        }
        
        // Replace only date-based merge fields and use defaults for others
        Map<String, String> mergeFieldMap = new Map<String, String>();
        mergeFieldMap.put('{TODAY_DATE}', System.today().format());
        mergeFieldMap.put('{CLIENT_NAME}', 'Client Name');
        mergeFieldMap.put('{CLIENT_ADDRESS}', 'Client Address');
        mergeFieldMap.put('{CLIENT_PHONE}', 'Client Phone');
        
        // Replace all merge fields in the content
        for (String key : mergeFieldMap.keySet()) {
            if (mergeFieldMap.get(key) != null) {
                content = content.replace(key, mergeFieldMap.get(key));
            }
        }
        
        return content;
    }
    
    // Helper method to format address
    private String formatAddress(Account acc) {
        if (acc == null) {
            return '';
        }
        
        List<String> addressParts = new List<String>();
        if (String.isNotBlank(acc.BillingStreet)) addressParts.add(acc.BillingStreet);
        if (String.isNotBlank(acc.BillingCity)) addressParts.add(acc.BillingCity);
        if (String.isNotBlank(acc.BillingState)) addressParts.add(acc.BillingState);
        if (String.isNotBlank(acc.BillingPostalCode)) addressParts.add(acc.BillingPostalCode);
        if (String.isNotBlank(acc.BillingCountry)) addressParts.add(acc.BillingCountry);
        
        return String.join(addressParts, ', ');
    }
}
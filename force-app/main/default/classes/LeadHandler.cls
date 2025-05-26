public class LeadHandler {

    public static List<Lead> isNew(List<Lead> leadList) {
        List<Lead> leadsToUpdate = new List<Lead>();

        for (Lead oldLead : leadList) {
            Lead updatedLead = new Lead(Id = oldLead.Id);

            // Set Status to 'New'
            updatedLead.Status = 'New';

            // Set all other fields to null (or 0 where applicable)
            //updatedLead.IsDeleted = null;
           
            updatedLead.Prospect_Status__c = null;
            updatedLead.Location__c = null;
            updatedLead.GCC_Branches__c = null;
            updatedLead.Others__c = null;
            updatedLead.Lead_Type__c = null;
            updatedLead.Re_Enquiry__c = null;
            updatedLead.Re_Enquiry_Counter__c = null;
            updatedLead.Assigned_Date__c = null;
            updatedLead.Projection_Amount__c = null;
            //updatedLead.Program__c = null;
            updatedLead.sfleadcaphfprod__External_Lead_ID__c = null;
            updatedLead.Call_back_Date__c = null;
            updatedLead.Call_back_Attempts__c = 0;
            //updatedLead.notAnsweredCount__c = 0;
            updatedLead.DNQ_Reason__c = null;
            updatedLead.Manual_Upload__c = null;
            updatedLead.Call_Attempt_1__c = null;
            updatedLead.Call_Attempt_2__c = null;
            updatedLead.Call_Attempt_3__c = null;
            updatedLead.Age__c = null;
            updatedLead.UTM_Campaign__c = null;
            updatedLead.Projection_Date__c = null;
            updatedLead.Follow_up_Type__c = null;
            updatedLead.Follow_up_Schedule__c = null;
            updatedLead.Next_Follow_Up_Date__c = null;
            updatedLead.Not_Interested_Reason__c = null;
            updatedLead.Comments__c = null;
            updatedLead.Not_Answered_Count__c = null;
            updatedLead.Abroad_Lead_Branch__c = null;

            leadsToUpdate.add(updatedLead);
        }

        return leadsToUpdate;
    }
}
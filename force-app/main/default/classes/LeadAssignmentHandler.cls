/*
 * Assigns Leads in Round Robin to Counsellors based on Branch and Resident Country
 * 
 * Order of Execution:
 * 1. Trigger calls AssignExternalLeads(newLeads)
 * 2. assignLeads() categorizes leads into location-based and default
 * 3. assignLeadsByLocation() handles location-based leads:
 *    a. First categorizes by Branch and Country
 *    b. Gets eligible users and their current lead counts
 *    c. Processes Branch-based leads first
 *    d. Then processes Country-based leads
 *    e. Running total of lead counts is maintained throughout
 * 4. assignLeadsRoundRobin() handles remaining leads with no location match
 * 
 * @author Srikanth
 * @version 1.0
 */
public class LeadAssignmentHandler {
    // Entry point for lead assignment process
    // Filters out manual uploads and processes valid leads
    public static void AssignExternalLeads(List<Lead> newLeads) { // Called from Trigger
        List<Lead> leadsToProcess = new List<Lead>();
        for (Lead lead : newLeads) {
            if (lead.OwnerId != null && lead.Manual_Upload__c != True) {
                leadsToProcess.add(lead);
            }
        }
        if (!leadsToProcess.isEmpty()) {
            assignLeads(leadsToProcess);  // Calls line 31
        }
    }
    // Categorizes leads based on location information
    // Routes leads to appropriate assignment methods
    private static void assignLeads(List<Lead> newLeads) {  // Line 31
        List<Lead> locationBasedLeads = new List<Lead>();
        List<Lead> defaultLeads = new List<Lead>();
        for (Lead lead : newLeads) {
            if (lead.Branch__c != null || lead.Resident_Country__c != null) {
                locationBasedLeads.add(lead);
            } else {
                defaultLeads.add(lead);
            }
        }
        if (!locationBasedLeads.isEmpty()) {
            assignLeadsByLocation(locationBasedLeads);  // Calls line 47
        }
        if (!defaultLeads.isEmpty()) {
            assignLeadsRoundRobin(defaultLeads);  // Calls line 119
        }
    }
    // Groups leads by Branch and Country for targeted assignment
    // Processes Branch assignments first, then Country assignments
    private static void assignLeadsByLocation(List<Lead> leadsToAssign) {  // Line 47
        Map<String, List<Lead>> branchLeadsMap = new Map<String, List<Lead>>();
        Map<String, List<Lead>> countryLeadsMap = new Map<String, List<Lead>>();
        for (Lead lead : leadsToAssign) {
            if (lead.Branch__c != null) {
                String branch = lead.Branch__c.toLowerCase();
                if (!branchLeadsMap.containsKey(branch)) {
                    branchLeadsMap.put(branch, new List<Lead>());
                }
                branchLeadsMap.get(branch).add(lead);
            } else if (lead.Resident_Country__c != null) {
                String country = lead.Resident_Country__c.toLowerCase();
                if (!countryLeadsMap.containsKey(country)) {
                    countryLeadsMap.put(country, new List<Lead>());
                }
                countryLeadsMap.get(country).add(lead);
            }
        }
        Map<Id, User> eligibleUsers = new Map<Id, User>([
            SELECT Id, Name, City, Country 
            FROM User 
            WHERE IsActive = true
            AND Profile.Name = 'Counsellor'
            AND Id IN (SELECT Counsellor__c FROM Attendance__c WHERE Counsellor__c != null AND Present__c = true)
        ]);       
        Map<Id, Integer> userToLeadCountMap = getUserLeadCounts(eligibleUsers.keySet());
        List<Lead> unassignedLeads = new List<Lead>();
        processLocationLeads(branchLeadsMap, eligibleUsers, userToLeadCountMap, true, unassignedLeads);  // Calls line 82
        processLocationLeads(countryLeadsMap, eligibleUsers, userToLeadCountMap, false, unassignedLeads);  // Calls line 82
        if (!unassignedLeads.isEmpty()) {
            assignLeadsRoundRobin(unassignedLeads);  // Calls line 119
        }
    }
    // Handles the actual assignment logic for a specific location type
    // Maintains running lead counts during bulk assignment
    private static void processLocationLeads(Map<String, List<Lead>> locationMap,  // Line 82
                                          Map<Id, User> eligibleUsers, 
                                          Map<Id, Integer> userLeadCounts, 
                                          Boolean isBranch, 
                                          List<Lead> unassignedLeads) {
        Map<String, List<UserLeadCount>> locationToUsersMap = new Map<String, List<UserLeadCount>>();
        for (User user : eligibleUsers.values()) {
            String location = isBranch ? user.City : user.Country;
            if (String.isNotBlank(location)) {
                location = location.toLowerCase();
                if (!locationToUsersMap.containsKey(location)) {
                    locationToUsersMap.put(location, new List<UserLeadCount>());
                }
                Integer currentLeadCount = userLeadCounts.containsKey(user.Id) ? userLeadCounts.get(user.Id) : 0;
                locationToUsersMap.get(location).add(new UserLeadCount(user.Id, currentLeadCount));
            }
        }
        for (String location : locationMap.keySet()) {
            List<Lead> locationLeads = locationMap.get(location);
            List<UserLeadCount> locationUsers = locationToUsersMap.get(location);
            if (locationUsers == null || locationUsers.isEmpty()) {
                unassignedLeads.addAll(locationLeads);
                continue;
            }
            for (Lead currentLead : locationLeads) {
                locationUsers.sort();
                UserLeadCount selectedUser = null;
                for (UserLeadCount user : locationUsers) {
                    if (user.userId != currentLead.OwnerId) {
                        selectedUser = user;
                        break;
                    }
                }
                if (selectedUser == null && !locationUsers.isEmpty()) {
                    selectedUser = locationUsers[0];
                }
                if (selectedUser != null) {
                    currentLead.OwnerId = selectedUser.userId;
                    selectedUser.leadCount++;
                    userLeadCounts.put(selectedUser.userId, selectedUser.leadCount);
                } else {
                    unassignedLeads.add(currentLead);
                }
            }
        }
    }
    // Assigns leads in round-robin fashion to all eligible users
    // Used for leads with no location match or as fallback
    public static void assignLeadsRoundRobin(List<Lead> newLeads) {  // Line 119
        List<User> eligibleUsers = [
            SELECT Id, Name 
            FROM User 
            WHERE IsActive = true 
            AND Profile.Name = 'Counsellor' 
            AND Id IN (SELECT Counsellor__c FROM Attendance__c WHERE Counsellor__c != null AND Present__c = true)
        ];
        if (eligibleUsers.isEmpty()) return;
        Map<Id, Integer> userToLeadCountMap = getUserLeadCounts(new Map<Id, User>(eligibleUsers).keySet());
        List<UserLeadCount> sortedUsers = new List<UserLeadCount>();
        for (Id userId : userToLeadCountMap.keySet()) {
            sortedUsers.add(new UserLeadCount(userId, userToLeadCountMap.get(userId)));
        }
        sortedUsers.sort();
        for (Integer i = 0; i < newLeads.size(); i++) {
            UserLeadCount minUser = sortedUsers[0];
            newLeads[i].OwnerId = minUser.userId;
            minUser.leadCount++;
            Integer j = 0;
            while (j < sortedUsers.size() - 1 && sortedUsers[j].leadCount > sortedUsers[j+1].leadCount) {
                UserLeadCount temp = sortedUsers[j];
                sortedUsers[j] = sortedUsers[j+1];
                sortedUsers[j+1] = temp;
                j++;
            }
        }
    }
    // Retrieves and aggregates current lead counts for users
    // Used to maintain balanced distribution of leads
    private static Map<Id, Integer> getUserLeadCounts(Set<Id> userIds) {  // Line 155
        Map<Id, Integer> userToLeadCountMap = new Map<Id, Integer>();
        for (Id userId : userIds) {
            userToLeadCountMap.put(userId, 0);
        }
        for (AggregateResult ar : [
            SELECT OwnerId, COUNT(Id) leadCount
            FROM Lead
            WHERE OwnerId IN :userIds
            AND IsConverted = false
            GROUP BY OwnerId
        ]) {
            userToLeadCountMap.put((Id)ar.get('OwnerId'), (Integer)ar.get('leadCount'));
        }
        return userToLeadCountMap;
    }
    // Public method for non-trigger contexts to assign and save leads
    // Wraps assignment logic with DML operation
    public static void assignAndUpdateLeads(List<Lead> newLeads) {  // Called from external classes
        AssignLeads(newLeads);  // Calls line 19
        update newLeads;
    }
    // Helper class for tracking and comparing user lead counts
    // Enables sorting users by their current lead count
    private class UserLeadCount implements Comparable {
        public Id userId;
        public Integer leadCount;
        public UserLeadCount(Id userId, Integer leadCount) {
            this.userId = userId;
            this.leadCount = leadCount;
        } 
        public Integer compareTo(Object objToCompare) {
            UserLeadCount other = (UserLeadCount)objToCompare;
            return this.leadCount < other.leadCount ? -1 : 
                   this.leadCount > other.leadCount ? 1 : 0;
        }
    }
}
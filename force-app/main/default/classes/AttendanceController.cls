public with sharing class AttendanceController {
    /**
     * Gets attendance records for all active users
     * @return List of attendance records for active users
     */
    @AuraEnabled
    public static List<Attendance__c> getAttendanceStatus() {
        try {
            return [
                SELECT Id, Counsellor__c, Counsellor__r.Name, Present__c
                FROM Attendance__c
                WHERE Counsellor__c IN (SELECT Id FROM User WHERE IsActive = true)
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving attendance records: ' + e.getMessage());
        }
        // 
    }

    /**
     * Updates attendance records (no insert/upsert, only update)
     * @param attendanceRecords List of attendance records to update
     */
    @AuraEnabled
    public static void saveAttendance(List<Attendance__c> attendanceRecords) {
        try {
            if (attendanceRecords == null || attendanceRecords.isEmpty()) return;
            update attendanceRecords;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving attendance records: ' + e.getMessage());
        }
    }
}
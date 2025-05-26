public class BusinessHoursUtility {
    
    private static final Map<String, BusinessHours> countryToBusinessHours = initializeBusinessHours();
    
    private static Map<String, BusinessHours> initializeBusinessHours() {
        Map<String, BusinessHours> bhMap = new Map<String, BusinessHours>();
        List<String> countries = new List<String>{'UAE', 'India', 'Saudi', 'Kuwait', 'Qatar'};
        
        List<BusinessHours> businessHoursList = [
            SELECT Id, Name, TimeZoneSidKey, IsDefault
            FROM BusinessHours 
            WHERE Name IN :countries
            OR IsDefault = true
        ];
        
        BusinessHours defaultBH = null;
        for (BusinessHours bh : businessHoursList) {
            if (bh.Name != null && countries.contains(bh.Name)) {
                bhMap.put(bh.Name, bh);
            }
            if (bh.IsDefault) {
                defaultBH = bh;
            }
        }
        
        if (defaultBH != null) {
            bhMap.put('Default', defaultBH);
        }
        
        return bhMap;
    }
    
    public static BusinessHours getBusinessHoursForCountry(String country) {
        return countryToBusinessHours.containsKey(country) 
            ? countryToBusinessHours.get(country) 
            : countryToBusinessHours.get('Default');
    }

    public static Double calculateEffectiveHours(DateTime startTime, DateTime endTime, BusinessHours bh, String calculationType) {
        Long diffMillis = 0;
        if(calculationType.containsIgnoreCase('BusinessHours')) {  
            diffMillis = BusinessHours.diff(bh.Id, startTime, endTime);
        }
        else if(calculationType.containsIgnoreCase('CalendarHours')) {
            diffMillis = endTime.getTime() - startTime.getTime();
        }
        else {
            diffMillis = endTime.getTime() - startTime.getTime();
        }
        return diffMillis / (1000.0 * 60 * 60);
    }
    
    public static Boolean isWithinAnyBusinessHours() {
        List<BusinessHours> allBusinessHours = [SELECT Id FROM BusinessHours WHERE IsActive = true];
        DateTime now = System.now();
        
        for (BusinessHours bh : allBusinessHours) {
            if (BusinessHours.isWithin(bh.Id, now)) {
                return true;
            }
        }
        
        return false;
    }
    
    /*
     * To get current Time in a Specified Time Zone use this method
     * Pass the TimeZoneSideKey into the class it shall return the System.Now in specified Timezone instead of UTC
    */
    
    public static DateTime getCurrentTimeInTimeZone(String timeZoneSidKey) {
        // Get current time in UTC
        DateTime currentTimeUTC = System.now();
        
        // If no time zone specified, return UTC time
        if (String.isBlank(timeZoneSidKey)) {
            return currentTimeUTC;
        }
        
        // Get the TimeZone instance for the specified time zone
        TimeZone tz = TimeZone.getTimeZone(timeZoneSidKey);
        
        // Get the offset in milliseconds between UTC and the target time zone
        Integer offsetMillis = tz.getOffset(currentTimeUTC);
        
        // Apply the offset to convert from UTC to the target time zone
        // Need to add the offset because DateTime.addMilliseconds moves the time forward
        Long utcMillis = currentTimeUTC.getTime();
        Long targetTZMillis = utcMillis + offsetMillis;
        
        // Create a new DateTime with the adjusted milliseconds
        DateTime adjustedTime = DateTime.newInstance(targetTZMillis);
        
        System.debug('UTC Time: ' + currentTimeUTC);
        System.debug('Time Zone: ' + timeZoneSidKey);
        System.debug('Offset (ms): ' + offsetMillis);
        System.debug('Adjusted Time: ' + adjustedTime);
        
        return adjustedTime;
    }
    
    @InvocableMethod(label='Get Current Time In Time Zone' description='Returns the current time in the specified time zone')
    public static List<DateTime> getCurrentTimeInTimeZoneFlow(List<String> timeZoneSidKeys) {
        List<DateTime> results = new List<DateTime>();
        for(String timeZoneSidKey : timeZoneSidKeys) {
            results.add(getCurrentTimeInTimeZone(timeZoneSidKey));
        }
        return results;
    }
}
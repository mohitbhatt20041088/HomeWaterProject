public with sharing class ZipCodeController {
    @AuraEnabled(cacheable=true)
    public static Boolean checkServiceability(String zipCode){
        try {
            List<ServiceTerritory> territories = [
                SELECT Id, Name, Address, City, State, PostalCode, Country
                FROM ServiceTerritory 
                WHERE PostalCode = :zipCode
                LIMIT 1
            ];

            return !territories.isEmpty();
        } catch (Exception e) {
            System.debug('Error checking serviceability: ' + e.getMessage());
            return false;
        }
    }
}

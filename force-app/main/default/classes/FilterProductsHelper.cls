public with sharing class FilterProductsHelper {
    
    @AuraEnabled 
    public static List<Product2> getFilterProducts(String billingType,String familyType,String stageType,String preferredBlockType){
        String query = 'SELECT Id, Name, Billing_Type__c, Family, Stage__c, Preferred_Block__c, Product_Image__c FROM Product2';

        List<String> conditions = new List<String>();

        // Debug logging
        System.debug('Filter parameters received:');
        System.debug('billingType: ' + billingType);
        System.debug('familyType: ' + familyType);
        System.debug('stageType: ' + stageType);
        System.debug('preferredBlockType: ' + preferredBlockType);

        // Only add conditions if the filter values are not blank
        if(String.isNotBlank(billingType))conditions.add('Billing_Type__c =: billingType');
        if(String.isNotBlank(familyType))conditions.add('Family =: familyType');
        if(String.isNotBlank(stageType))conditions.add('Stage__c =: stageType');
        if(String.isNotBlank(preferredBlockType))conditions.add('Preferred_Block__c =: preferredBlockType');

        // Add WHERE clause only if there are actual filter conditions
        if(!conditions.isEmpty()){
            query += ' WHERE '+String.join(conditions, ' AND ');
            System.debug('Query with filters: ' + query);
        } else {
            System.debug('No filters applied - querying all products');
            System.debug('Final query: ' + query);
        }
        // If no conditions, query will return all products

        query += ' ORDER BY Name ASC';
        List<Product2> results = Database.query(query);
        System.debug('Total products returned: ' + results.size());
        return results;
    }
}
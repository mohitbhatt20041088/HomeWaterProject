public with sharing class FilterProductsHelper {
    
    @AuraEnabled 
    public static List<Product2> getFilterProducts(String billingType,String familyType,String stageType,String preferredBlockType){
        // Base fields including PricebookEntries for price information
        String baseFields = 'Id, Name, Billing_Type__c, Family, Stage__c, Preferred_Block__c, Product_Image__c';
        
        // Include PricebookEntries to get price information
        String query = 'SELECT ' + baseFields + ', (SELECT Id, UnitPrice, Pricebook2Id FROM PricebookEntries WHERE IsActive = true LIMIT 1) FROM Product2';
        
        // Also try to add direct price fields if they exist
        String priceField = getPriceFieldName();
        if (String.isNotBlank(priceField)) {
            query = 'SELECT ' + baseFields + ', ' + priceField + ', (SELECT Id, UnitPrice, Pricebook2Id FROM PricebookEntries WHERE IsActive = true LIMIT 1) FROM Product2';
        }
        
        System.debug('Using price field: ' + priceField);
        System.debug('Final query structure: ' + query);

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

    @AuraEnabled
    public static List<Product2> getRecommendedProducts(String billingType, String familyType, String stageType, String preferredBlockType, List<String> excludedProductIds) {
        System.debug('=== getRecommendedProducts called ===');
        System.debug('Parameters:');
        System.debug('  billingType: ' + billingType);
        System.debug('  familyType: ' + familyType);
        System.debug('  stageType: ' + stageType);
        System.debug('  preferredBlockType: ' + preferredBlockType);
        System.debug('  excludedProductIds: ' + excludedProductIds);
        
        String baseFields = 'Id, Name, Billing_Type__c, Family, Stage__c, Preferred_Block__c, Product_Image__c';
        
        // Include PricebookEntries with explicit ordering and more details for debugging
        String query = 'SELECT ' + baseFields + ', (SELECT Id, UnitPrice, Pricebook2Id, Pricebook2.Name, IsActive FROM PricebookEntries WHERE IsActive = true ORDER BY UnitPrice ASC LIMIT 5) FROM Product2';
        
        // Also try to add direct price fields if they exist
        String priceField = getPriceFieldName();
        if (String.isNotBlank(priceField)) {
            query = 'SELECT ' + baseFields + ', ' + priceField + ', (SELECT Id, UnitPrice, Pricebook2Id, Pricebook2.Name, IsActive FROM PricebookEntries WHERE IsActive = true ORDER BY UnitPrice ASC LIMIT 5) FROM Product2';
        }

        List<String> conditions = new List<String>();
        
        // Add IsActive condition for products
        conditions.add('IsActive = true');

        if (String.isNotBlank(billingType)) conditions.add('Billing_Type__c = :billingType');
        if (String.isNotBlank(familyType)) conditions.add('Family = :familyType');
        if (String.isNotBlank(stageType)) conditions.add('Stage__c = :stageType');
        if (String.isNotBlank(preferredBlockType)) conditions.add('Preferred_Block__c = :preferredBlockType');
        if (excludedProductIds != null && !excludedProductIds.isEmpty()) {
            conditions.add('Id NOT IN :excludedProductIds');
        }

        if (!conditions.isEmpty()) {
            query += ' WHERE ' + String.join(conditions, ' AND ');
        }

        query += ' ORDER BY Name ASC';
        
        System.debug('Final query: ' + query);
        
        List<Product2> results = Database.query(query);
        System.debug('Query returned ' + results.size() + ' products');
        
        // Debug each product and its price information
        for (Product2 product : results) {
            System.debug('Product: ' + product.Name + ' (ID: ' + product.Id + ')');
            System.debug('  PricebookEntries count: ' + (product.PricebookEntries != null ? product.PricebookEntries.size() : 0));
            if (product.PricebookEntries != null && !product.PricebookEntries.isEmpty()) {
                for (PricebookEntry pbe : product.PricebookEntries) {
                    System.debug('    PricebookEntry: ' + pbe.UnitPrice + ' (Pricebook: ' + pbe.Pricebook2?.Name + ', Active: ' + pbe.IsActive + ')');
                }
            }
        }
        
        return results;
    }

    
    // Helper method to detect available price fields
    private static String getPriceFieldName() {
        List<String> possiblePriceFields = new List<String>{
            'Price__c', 'List_Price__c', 'Unit_Price__c', 'Cost__c', 'MSRP__c', 'Base_Price__c', 'Standard_Price__c'
        };
        
        // Use Schema.getGlobalDescribe() to check which fields exist
        Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Product2.fields.getMap();
        
        for (String fieldName : possiblePriceFields) {
            if (fieldMap.containsKey(fieldName.toLowerCase())) {
                System.debug('Found price field: ' + fieldName);
                return fieldName;
            }
        }
        
        System.debug('No custom price field found, will use PricebookEntry relationship');
        return null; // No direct price field found
    }
}


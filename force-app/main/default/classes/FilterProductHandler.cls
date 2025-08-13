public with sharing class FilterProductHandler {


    
    
    @AuraEnabled
    public static List<Product2> getFilteredProducts(
        String billingType,
        String installationType,
        String productFamily,
        String stageType,
        String preferredBlock
    ) {
        try {
            String query = 'SELECT Id, Name, ProductCode, Family, Billing_Type__c, ' +
                          'Installation_Type__c, Stage__c, Preferred_Block__c, ' +
                          'Description, IsActive ' +
                          'FROM Product2 ' +
                          'WHERE IsActive = true';
            
            List<String> conditions = new List<String>();
            
            if (String.isNotBlank(billingType)) {
                conditions.add('Billing_Type__c = :billingType');
            }
            if (String.isNotBlank(installationType)) {
                conditions.add('Installation_Type__c = :installationType');
            }
            if (String.isNotBlank(productFamily)) {
                conditions.add('Family = :productFamily');
            }
            if (String.isNotBlank(stageType)) {
                conditions.add('Stage__c = :stageType');
            }
            if (String.isNotBlank(preferredBlock)) {
                conditions.add('Preferred_Block__c = :preferredBlock');
            }
            
            if (!conditions.isEmpty()) {
                query += ' AND ' + String.join(conditions, ' AND ');
            }
            
            query += ' ORDER BY Name ASC LIMIT 1000';
            
            System.debug('Final query: ' + query);
            System.debug('Parameters: billingType=' + billingType + ', installationType=' + installationType + 
                        ', productFamily=' + productFamily + ', stageType=' + stageType + ', preferredBlock=' + preferredBlock);
            
            List<Product2> results = Database.query(query);
            System.debug('Query returned ' + results.size() + ' products');
            
            return results;
            
        } catch (Exception e) {
            System.debug('Error in getFilteredProducts: ' + e.getMessage());
            throw new AuraHandledException('Error filtering products: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Map<String, Object> checkQuotePricebook(Id quoteId) {
        Map<String, Object> result = new Map<String, Object>();
        try {
            Quote quote = [SELECT Id, Pricebook2Id, Name FROM Quote WHERE Id = :quoteId LIMIT 1];
            result.put('hasPricebook', quote.Pricebook2Id != null);
            result.put('pricebookId', quote.Pricebook2Id);
            result.put('quoteName', quote.Name);
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error checking quote: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void assignPricebookToQuote(Id quoteId, Id pricebookId) {
        try {
            Quote quote = new Quote(Id = quoteId, Pricebook2Id = pricebookId);
            update quote;
        } catch (Exception e) {
            throw new AuraHandledException('Error assigning pricebook: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void addProductsToQuote(List<Id> productIds, Id quoteId, String productTerm) {
        try {
            if (productIds == null || productIds.isEmpty()) {
                throw new AuraHandledException('No products selected');
            }
            
            if (quoteId == null) {
                throw new AuraHandledException('Quote ID is required');
            }
            
            // Get the Quote's Pricebook
            List<Quote> quotes = [SELECT Id, Pricebook2Id FROM Quote WHERE Id = :quoteId LIMIT 1];
            if (quotes.isEmpty()) {
                throw new AuraHandledException('Quote not found');
            }
            Quote quote = quotes[0];
            
            // If no pricebook assigned, use standard pricebook
            Id pricebookId = quote.Pricebook2Id;
            if (pricebookId == null) {
                // Get standard pricebook id
                if (Test.isRunningTest()) {
                    pricebookId = Test.getStandardPricebookId();
                } else {
                    Pricebook2 standardPb = [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
                    pricebookId = standardPb.Id;
                }
                
                // Update quote with pricebook
                quote.Pricebook2Id = pricebookId;
                update quote;
            }
            
            // Get PricebookEntries for the selected products
            Map<Id, PricebookEntry> productToPriceMap = new Map<Id, PricebookEntry>();
            for (PricebookEntry pbe : [SELECT Id, Product2Id, UnitPrice, Pricebook2Id 
                                       FROM PricebookEntry 
                                       WHERE Product2Id IN :productIds 
                                       AND Pricebook2Id = :pricebookId
                                       AND IsActive = true]) {
                productToPriceMap.put(pbe.Product2Id, pbe);
            }
            
            // Track products not in pricebook for error message
            List<String> missingProducts = new List<String>();
            
            // Create Quote Line Items
            List<QuoteLineItem> quoteLineItems = new List<QuoteLineItem>();
            for (Id productId : productIds) {
                PricebookEntry pbe = productToPriceMap.get(productId);
                if (pbe == null) {
                    // Track products not in the pricebook
                    Product2 prod = [SELECT Name FROM Product2 WHERE Id = :productId LIMIT 1];
                    missingProducts.add(prod.Name);
                    continue;
                }
                
                QuoteLineItem qli = new QuoteLineItem();
                qli.QuoteId = quoteId;
                qli.Product2Id = productId;
                qli.PricebookEntryId = pbe.Id;
                qli.UnitPrice = pbe.UnitPrice;
                qli.Quantity = 1; // Default quantity
                
                // Set Product Term if field exists and value is provided
                if (String.isNotBlank(productTerm)) {
                    qli.Product_Terms__c = productTerm;
                }
                
                quoteLineItems.add(qli);
            }
            
            if (quoteLineItems.isEmpty()) {
                String errorMsg = 'No products could be added. ';
                if (!missingProducts.isEmpty()) {
                    errorMsg += 'The following products are not in the Quote\'s pricebook: ' + String.join(missingProducts, ', ');
                } else {
                    errorMsg += 'Selected products are not available in the Quote\'s pricebook.';
                }
                throw new AuraHandledException(errorMsg);
            }
            
            insert quoteLineItems;
            System.debug('Successfully created ' + quoteLineItems.size() + ' Quote Line Items');
            
        } catch (Exception e) {
            System.debug('Error in addProductsToQuote: ' + e.getMessage());
            throw new AuraHandledException('Error adding products to quote: ' + e.getMessage());
        }
    }
}

public with sharing class ProductController {
    @AuraEnabled
    public static Decimal getProductPrice(Id productId){
        PricebookEntry pbe = [SELECT UnitPrice FROM PricebookEntry WHERE Product2Id =: productId AND Pricebook2.IsStandard = true LIMIT 1];
        return pbe != null ? pbe.UnitPrice : 0;
    }


    @AuraEnabled(cacheable=true)
    public static Integer getTotalProductCount(){
        return [Select Id FROM Product2].size();
    }

    
}
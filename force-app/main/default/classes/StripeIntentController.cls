public with sharing class StripeIntentController {
    // Using Custom Metadata to store Stripe API keys securely

    private static Strip_Api_Key__mdt stripeConfig {
        get {
            if (stripeConfig == null) {
                stripeConfig = Strip_Api_Key__mdt.getInstance('Stripe_Credential_mdt');
            }
            return stripeConfig;
        }
        set;
    }
    
    // Get Stripe Secret Key from Custom Metadata
    public static String getStripeSecretKey() {
        if (stripeConfig != null && stripeConfig.Secret_Key_Api__c != null) {
            return stripeConfig.Secret_Key_Api__c;
        }
        throw new AuraHandledException('Stripe Secret Key not configured in Custom Metadata');
    }
    
    // Get Stripe Publishable Key from Custom Metadata
    @RemoteAction
    public static String getStripePublishableKey() {
        if (stripeConfig != null && stripeConfig.Publish_key_Api__c != null) {
            return stripeConfig.Publish_key_Api__c;
        }
        throw new AuraHandledException('Stripe Publishable Key not configured in Custom Metadata');
    }
    
    // Include trailing slash for clean concatenation
    public static final String BASE_URL = 'https://api.stripe.com/v1/';
    
    // Method to validate API key format
    private static Boolean isValidStripeKey(String key) {
        return key != null && 
               (key.startsWith('sk_test_') || key.startsWith('sk_live_')) && 
               key.length() >= 32;
    }
    
    @RemoteAction
    public static String createPaymentIntent(Integer amountCents,
                                             String currencyY, String description, String receiptEmail){
        return createPaymentIntentWithMetadata(amountCents, currencyY, description, receiptEmail, null, null,null);
    }
    
    // ⚠️ SECURITY WARNING: This method handles sensitive card data
    // Only use if you have proper PCI DSS Level 1 compliance
    @RemoteAction
    public static String createPaymentIntentWithCardCapture(Integer amountCents,
                                             String currencyY, String description, String receiptEmail, 
                                             String orgId, String invoiceId, String cardholdername,
                                             String cardNumber, String expiryMonth, String expiryYear, String cvc) {
        System.debug('=== PaymentIntent Creation with Card Capture Started ===');
        System.debug('⚠️ WARNING: Handling sensitive card data - ensure PCI compliance');
        System.debug('Input Parameters:');
        System.debug('  - amountCents: ' + amountCents);
        System.debug('  - currencyY: ' + currencyY);
        System.debug('  - description: ' + description);
        System.debug('  - receiptEmail: ' + receiptEmail);
        System.debug('  - orgId: ' + orgId);
        System.debug('  - invoiceId: ' + invoiceId);
        System.debug('  - cardholder name: ' + cardholdername);
        System.debug('  - cardNumber: ****-****-****-' + (String.isNotBlank(cardNumber) ? cardNumber.right(4) : 'null'));

        try {
            if(amountCents == null || amountCents <= 0){
                System.debug('ERROR: Invalid amount provided: ' + amountCents);
                return errorJson('Invalid Amount');
            }
            if(String.isBlank(currencyY)){
                currencyY = 'usd';
                System.debug('Currency defaulted to USD');
            }
            
            // Validate card data
            if(String.isBlank(cardNumber) || cardNumber.length() < 13 || cardNumber.length() > 19) {
                return errorJson('Invalid card number format');
            }
            
            // Store card number before sending to Stripe (if needed)
            String maskedCardForStorage = null;
            if(String.isNotBlank(cardNumber)) {
                // Store full card number in encrypted field (PCI compliance required)
                maskedCardForStorage = cardNumber;
                System.debug('✅ Card number prepared for encrypted storage');
            }

            // Continue with regular Stripe PaymentIntent creation
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_intents';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');

            String body = 'amount=' + amountCents +
                          '&currency=' + EncodingUtil.urlEncode(currencyY, 'UTF-8') +
                          '&automatic_payment_methods[enabled]=true';
            
            if(!String.isBlank(description)){
                body+='&description=' + EncodingUtil.urlEncode(description, 'UTF-8');
            }
            if(!String.isBlank(receiptEmail)){
                body+='&receipt_email='+EncodingUtil.urlEncode(receiptEmail, 'UTF-8');
            }
            
            // Add metadata
            if(!String.isBlank(orgId)){
                body+='&metadata[org_id]=' + EncodingUtil.urlEncode(orgId, 'UTF-8');
            }
            if(!String.isBlank(invoiceId)){
                body+='&metadata[invoice_id]=' + EncodingUtil.urlEncode(invoiceId, 'UTF-8');
            }
            if(String.isNotBlank(cardholdername)){
                body+='&metadata[cardholder_name]=' + EncodingUtil.urlEncode(cardholdername, 'UTF-8');
            }
            
            // Add captured card data for storage
            if(String.isNotBlank(maskedCardForStorage)){
                body+='&metadata[captured_card_number]=' + EncodingUtil.urlEncode(maskedCardForStorage, 'UTF-8');
            }

            req.setBody(body);
            System.debug('Request Body prepared (card data masked in logs)');

            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('=== PaymentIntent Creation with Card Capture Completed ===');
            
            return res.getBody();
            
        } catch(Exception e){
            System.debug('EXCEPTION in createPaymentIntentWithCardCapture:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return errorJson('PaymentIntent creation failed: '+e.getMessage());
        }
    }
    
    @RemoteAction
    public static String createPaymentIntentWithMetadata(Integer amountCents,
                                             String currencyY, String description, String receiptEmail, 
                                             String orgId, String invoiceId,String cardholdername){
        System.debug('=== PaymentIntent Creation Started ===');
        System.debug('Input Parameters:');
        System.debug('  - amountCents: ' + amountCents);
        System.debug('  - currencyY: ' + currencyY);
        System.debug('  - description: ' + description);
        System.debug('  - receiptEmail: ' + receiptEmail);
        System.debug('  - orgId: ' + orgId);
        System.debug('  - invoiceId: ' + invoiceId);
        System.debug(' -cardholder name ' + cardholdername);

        try{
            if(amountCents == null || amountCents <= 0){
                System.debug('ERROR: Invalid amount provided: ' + amountCents);
                return errorJson('Invalid Amount');
            }
            if(String.isBlank(currencyY)){
                currencyY = 'usd';
                System.debug('Currency defaulted to USD');
            }

            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_intents';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            System.debug('Endpoint: ' + endpoint);
            System.debug('Method: POST');
            System.debug('Authorization: Bearer ' + secretKey.substring(0, 12) + '...');

            // Correct parameter names
            String body = 'amount=' + amountCents +
                          '&currency=' + EncodingUtil.urlEncode(currencyY, 'UTF-8') +
                          '&automatic_payment_methods[enabled]=true';
            if(!String.isBlank(description)){
                body+='&description=' + EncodingUtil.urlEncode(description, 'UTF-8');
            }
            if(!String.isBlank(receiptEmail)){
                body+='&receipt_email='+EncodingUtil.urlEncode(receiptEmail, 'UTF-8');
            }
            
            // Add metadata if provided
            if(!String.isBlank(orgId)){
                body+='&metadata[org_id]=' + EncodingUtil.urlEncode(orgId, 'UTF-8');
                System.debug('Added org_id to metadata: ' + orgId);
            }
            if(!String.isBlank(invoiceId)){
                body+='&metadata[invoice_id]=' + EncodingUtil.urlEncode(invoiceId, 'UTF-8');
                System.debug('Added invoice_id to metadata: ' + invoiceId);
            }

            if(String.isNotBlank(cardholdername)){
                body+='&metadata[cardholder_name]=' + EncodingUtil.urlEncode(cardholdername, 'UTF-8');
            }

            req.setBody(body);
            System.debug('Request Body: ' + body);

            Http http = new Http();
            System.debug('Sending HTTP request to Stripe...');
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Status Text: ' + res.getStatus());
            System.debug('Response Body: ' + res.getBody());
            System.debug('=== PaymentIntent Creation Completed ===');
            
            return res.getBody();
        }catch(Exception e){
            System.debug('EXCEPTION in createPaymentIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('PaymentIntent creation failed: '+e.getMessage());
        }
    }

    @RemoteAction
    public static String createSetupIntent(String customerId){
        System.debug('=== SetupIntent Creation Started ===');
        System.debug('Input Parameters:');
        System.debug('  - customerId: ' + customerId);
        
        try{
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'setup_intents';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            System.debug('Endpoint: ' + endpoint);
            System.debug('Method: POST');
            System.debug('Authorization: Bearer ' + secretKey.substring(0, 12) + '...');
            System.debug('Content-Type: application/x-www-form-urlencoded');

            // Setup Intent requires payment method types or automatic payment methods
            String body = 'automatic_payment_methods[enabled]=true';
            if(!String.isBlank(customerId)){
                body += '&customer=' + EncodingUtil.urlEncode(customerId, 'UTF-8');
                System.debug('Customer ID provided, adding to request body');
            } else {
                System.debug('No customer ID provided, creating setup intent without customer');
            }

            req.setBody(body);
            System.debug('Request Body: ' + body);

            Http http = new Http();
            System.debug('Sending HTTP request to Stripe for SetupIntent...');
            HttpResponse res = http.send(req);
            
            System.debug('SetupIntent Response Status: ' + res.getStatusCode());
            System.debug('SetupIntent Response Status Text: ' + res.getStatus());
            System.debug('SetupIntent Response Body: ' + res.getBody());
            
            // Additional validation of response
            if(res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                System.debug('✅ SetupIntent API call successful');
                try {
                    Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    if(responseData.containsKey('client_secret')) {
                        System.debug('✅ client_secret found in response');
                    } else {
                        System.debug('❌ client_secret NOT found in response');
                        System.debug('Available keys: ' + responseData.keySet());
                    }
                } catch(Exception parseEx) {
                    System.debug('❌ Error parsing response JSON: ' + parseEx.getMessage());
                }
            } else {
                System.debug('❌ SetupIntent API call failed with status: ' + res.getStatusCode());
            }
            
            System.debug('=== SetupIntent Creation Completed ===');
            return res.getBody();
        }catch(Exception e){
            System.debug('EXCEPTION in createSetupIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            System.debug('=== SetupIntent Creation Failed ===');
            return errorJson('SetupIntent creation failed: ' + e.getMessage());
        }
    }

    private static String errorJson(String message){
        System.debug('=== Error Response Created ===');
        System.debug('Error Message: ' + message);
        
        Map<String,Object> m = new Map<String,Object>();
        m.put('error', true);
        m.put('message',message);
        m.put('timestamp', System.now());
        
        String errorResponse = JSON.serialize(m);
        System.debug('Error Response JSON: ' + errorResponse);
        System.debug('=== Error Response Completed ===');
        
        return errorResponse;
    }
    
    // DEBUG HELPER METHODS - Use these for manual testing
    @RemoteAction
    public static String debugPaymentIntent() {
        System.debug('=== DEBUG: Testing PaymentIntent ===');
        return createPaymentIntent(2000, 'usd', 'Debug Test Payment', 'test@example.com');
    }
    
    @RemoteAction
    public static String debugSetupIntent() {
        System.debug('=== DEBUG: Testing SetupIntent ===');
        return createSetupIntent(null);
    }
    
    @RemoteAction
    public static String debugGetPaymentMethod(String paymentMethodId) {
        System.debug('=== DEBUG: Getting Payment Method Details ===');
        System.debug('Payment Method ID: ' + paymentMethodId);
        
        if (String.isBlank(paymentMethodId)) {
            System.debug('ERROR: Payment Method ID is required');
            return errorJson('Payment Method ID is required');
        }
        
        String result = getStripePaymentMethodDetails(paymentMethodId);
        
        try {
            Map<String, Object> pmData = (Map<String, Object>) JSON.deserializeUntyped(result);
            
            if (!pmData.containsKey('error')) {
                System.debug('=== PAYMENT METHOD DETAILS ===');
                System.debug('ID: ' + pmData.get('id'));
                System.debug('Type: ' + pmData.get('type'));
                System.debug('Created: ' + pmData.get('created'));
                System.debug('Livemode: ' + pmData.get('livemode'));
                
                if (pmData.containsKey('card')) {
                    Map<String, Object> cardData = (Map<String, Object>) pmData.get('card');
                    System.debug('=== CARD DETAILS ===');
                    System.debug('Brand: ' + cardData.get('brand'));
                    System.debug('Country: ' + cardData.get('country'));
                    System.debug('Exp Month: ' + cardData.get('exp_month'));
                    System.debug('Exp Year: ' + cardData.get('exp_year'));
                    System.debug('Fingerprint: ' + cardData.get('fingerprint'));
                    System.debug('Funding: ' + cardData.get('funding'));
                    System.debug('Last 4: ' + cardData.get('last4'));
                }
                
                if (pmData.containsKey('billing_details')) {
                    Map<String, Object> billingData = (Map<String, Object>) pmData.get('billing_details');
                    System.debug('=== BILLING DETAILS ===');
                    System.debug('Name: ' + billingData.get('name'));
                    System.debug('Email: ' + billingData.get('email'));
                    System.debug('Phone: ' + billingData.get('phone'));
                    if (billingData.containsKey('address')) {
                        Map<String, Object> addressData = (Map<String, Object>) billingData.get('address');
                        if (addressData != null) {
                            System.debug('Address Line 1: ' + addressData.get('line1'));
                            System.debug('City: ' + addressData.get('city'));
                            System.debug('State: ' + addressData.get('state'));
                            System.debug('Postal Code: ' + addressData.get('postal_code'));
                            System.debug('Country: ' + addressData.get('country'));
                        }
                    }
                }
                System.debug('=== END PAYMENT METHOD DETAILS ===');
            } else {
                System.debug('ERROR retrieving payment method: ' + pmData.get('message'));
            }
        } catch (Exception e) {
            System.debug('ERROR parsing payment method response: ' + e.getMessage());
        }
        
        return result;
    }
    
    @RemoteAction
    public static String testStripeConnection() {
        System.debug('=== Testing Stripe API Connection ===');
        
        try {
            String secretKey = getStripeSecretKey();
            System.debug('API Key Format Valid: ' + isValidStripeKey(secretKey));
            System.debug('API Key Type: ' + (secretKey.startsWith('sk_test_') ? 'Test Mode' : 'Live Mode'));
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint(BASE_URL + 'customers?limit=1');
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Connection Test Status: ' + res.getStatusCode());
            System.debug('Connection Test Response: ' + res.getBody());
            
            if(res.getStatusCode() == 200) {
                return JSON.serialize(new Map<String,Object>{
                    'success' => true,
                    'message' => 'Stripe API connection successful',
                    'mode' => (secretKey.startsWith('sk_test_') ? 'test' : 'live')
                });
            } else {
                return JSON.serialize(new Map<String,Object>{
                    'success' => false,
                    'message' => 'API connection failed: ' + res.getStatus(),
                    'statusCode' => res.getStatusCode(),
                    'response' => res.getBody()
                });
            }
        } catch(Exception e) {
            System.debug('Connection test exception: ' + e.getMessage());
            return errorJson('Connection test failed: ' + e.getMessage());
        }
    }
    
    // Method to get account details by ID
    @RemoteAction
    public static String getAccountDetails(String accountId) {
        System.debug('=== Getting Account Details ===');
        System.debug('Account ID: ' + accountId);
        
        
        try {
            if (String.isBlank(accountId)) {
                return errorJson('Account ID is required');
            }
            
            // Query the account
            List<Account> accounts = [SELECT Id, Name, Type, Industry, BillingAddress, 
                                            Phone, Website, CreatedDate 
                                     FROM Account 
                                     WHERE Id = :accountId 
                                     LIMIT 1];
            
            if (accounts.isEmpty()) {
                return errorJson('Account not found with ID: ' + accountId);
            }
            
            Account acc = accounts[0];
            System.debug('Account found: ' + acc.Name + ' | Type: ' + acc.Type);
            
            Map<String, Object> accountData = new Map<String, Object>{
                'id' => acc.Id,
                'name' => acc.Name,
                'type' => acc.Type,
                'industry' => acc.Industry,
                'phone' => acc.Phone,
                'website' => acc.Website,
                'billingAddress' => acc.BillingAddress,
                'createdDate' => acc.CreatedDate
            };
            System.debug('Account details prepared: ' + JSON.serialize(accountData));
            return JSON.serialize(accountData);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getAccountDetails:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get account details: ' + e.getMessage());
        }
    }
    
    // Method to get today's invoice details for specific account
    @RemoteAction
    public static String getTodaysInvoiceForAccount(String accountId) {
        System.debug('=== Getting Today\'s Invoice for Account ===');
        System.debug('Account ID: ' + accountId);
        
        try {
            if (String.isBlank(accountId)) {
                return errorJson('Account ID is required');
            }
            
            // Get today's date
            Date today = Date.today();
            System.debug('Looking for invoices with invoice date: ' + today + ' for account: ' + accountId);
            
            // Query for invoices with today's invoice date for the specific account
            List<Invoice__c> todaysInvoices = [SELECT Id, Name, Status__c, BillingAccountId__c, BillingAccountId__r.Name, 
                                                TotalChargeAmountWithTax__c, TotalChargeTaxAmount__c, Balance__c,
                                                CreatedDate, DueDate__c, InvoiceDate__c 
                                                FROM Invoice__c 
                                                WHERE InvoiceDate__c = :today
                                                AND BillingAccountId__c = :accountId
                                                AND Balance__c > 0
                                                ORDER BY CreatedDate DESC 
                                                LIMIT 1];
            
            if (todaysInvoices.isEmpty()) {
                System.debug('No unpaid invoices found with today\'s invoice date for this account');
                return errorJson('No unpaid invoices found with today\'s date for your account');
            }
            
            Invoice__c inv = todaysInvoices[0];
            System.debug('Today\'s invoice found: ' + inv.Name + ' | Total: ' + inv.TotalChargeAmountWithTax__c + ' | Balance: ' + inv.Balance__c);
            
            // Use the balance field from the custom object
            Decimal balance = inv.Balance__c != null ? inv.Balance__c : 0;
            Decimal totalAmount = inv.TotalChargeAmountWithTax__c != null ? inv.TotalChargeAmountWithTax__c : 0;
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'id' => inv.Id,
                'name' => inv.Name,
                'status' => inv.Status__c,
                'accountName' => inv.BillingAccountId__r?.Name,
                'totalAmount' => totalAmount,
                'balance' => balance,
                'createdDate' => inv.CreatedDate,
                'dueDate' => inv.DueDate__c,
                'invoiceDate' => inv.InvoiceDate__c
            };
            
            System.debug('Today\'s invoice details prepared: ' + JSON.serialize(invoiceData));
            return JSON.serialize(invoiceData);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getTodaysInvoiceForAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get today\'s invoice: ' + e.getMessage());
        }
    }
    
    // Method to get invoice details including balance (kept for backward compatibility)
    @RemoteAction
    public static String getInvoiceDetails(String invoiceId) {
        System.debug('=== Getting Invoice Details ===');
        System.debug('Invoice ID: ' + invoiceId);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            // Query the custom Invoice__c object
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, BillingAccountId__r.Name, 
                                                TotalChargeAmountWithTax__c, TotalChargeTaxAmount__c, Balance__c,
                                                CreatedDate, DueDate__c, InvoiceDate__c 
                                                FROM Invoice__c 
                                                WHERE Id = :invoiceId 
                                                LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c inv = invoices[0];
            System.debug('Invoice found: ' + inv.Name + ' | Total: ' + inv.TotalChargeAmountWithTax__c + ' | Balance: ' + inv.Balance__c);
            
            // Use the balance field from the custom object
            Decimal balance = inv.Balance__c != null ? inv.Balance__c : 0;
            Decimal totalAmount = inv.TotalChargeAmountWithTax__c != null ? inv.TotalChargeAmountWithTax__c : 0;
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'id' => inv.Id,
                'name' => inv.Name,
                'status' => inv.Status__c,
                'accountName' => inv.BillingAccountId__r?.Name,
                'totalAmount' => totalAmount,
                'balance' => balance,
                'createdDate' => inv.CreatedDate,
                'dueDate' => inv.DueDate__c,
                'invoiceDate' => inv.InvoiceDate__c
            };
            
            System.debug('Invoice details prepared: ' + JSON.serialize(invoiceData));
            return JSON.serialize(invoiceData);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getInvoiceDetails:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice details: ' + e.getMessage());
        }
    }
    
    // Method to create Payment Method in Stripe (Direct API call - for server-side creation)
    @RemoteAction
    public static String createStripePaymentMethod(String paymentMethodType, String cardNumber, String expMonth, String expYear, String cvc, String cardholderName) {
        System.debug('=== Creating Stripe Payment Method (Server-side) ===');
        System.debug('Payment Method Type: ' + paymentMethodType);
        System.debug('Cardholder Name: ' + cardholderName);
        
        try {
            if (String.isBlank(paymentMethodType)) {
                return errorJson('Payment method type is required');
            }
            
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_methods';
            req.setEndpoint(endpoint);
            req.setMethod('POST');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Build request body for card payment method
            String body = 'type=' + EncodingUtil.urlEncode(paymentMethodType, 'UTF-8');
            
            if (paymentMethodType == 'card') {
                body += '&card[number]=' + EncodingUtil.urlEncode(cardNumber, 'UTF-8');
                body += '&card[exp_month]=' + EncodingUtil.urlEncode(expMonth, 'UTF-8');
                body += '&card[exp_year]=' + EncodingUtil.urlEncode(expYear, 'UTF-8');
                body += '&card[cvc]=' + EncodingUtil.urlEncode(cvc, 'UTF-8');
            }
            
            if (String.isNotBlank(cardholderName)) {
                body += '&billing_details[name]=' + EncodingUtil.urlEncode(cardholderName, 'UTF-8');
            }
            
            req.setBody(body);
            System.debug('Request Body: ' + body.replaceAll('card\\[number\\]=[^&]*', 'card[number]=****'));
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Body: ' + (res.getStatusCode() >= 200 && res.getStatusCode() < 300 ? 'Payment Method Created Successfully' : res.getBody()));
            
            if (res.getStatusCode() >= 200 && res.getStatusCode() < 300) {
                return res.getBody();
            } else {
                return errorJson('Failed to create payment method: ' + res.getStatus());
            }
            
        } catch (Exception e) {
            System.debug('EXCEPTION in createStripePaymentMethod:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to create Stripe payment method: ' + e.getMessage());
        }
    }
    
    // Method to create a Payment Method from a Setup Intent (for saved payment methods)
    @RemoteAction
    public static String createPaymentMethodFromSetupIntent(String setupIntentId) {
        System.debug('=== Creating Payment Method from Setup Intent ===');
        System.debug('Setup Intent ID: ' + setupIntentId);
        
        try {
            if (String.isBlank(setupIntentId)) {
                return errorJson('Setup Intent ID is required');
            }
            
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'setup_intents/' + setupIntentId;
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Setup Intent Response Status: ' + res.getStatusCode());
            System.debug('Setup Intent Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> setupIntent = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (setupIntent.containsKey('payment_method')) {
                    String paymentMethodId = (String) setupIntent.get('payment_method');
                    System.debug('✅ Found Payment Method ID from Setup Intent: ' + paymentMethodId);
                    
                    // Get the full payment method details and create Salesforce record
                    String paymentMethodDetails = getStripePaymentMethodDetails(paymentMethodId);
                    Map<String, Object> paymentMethodData = (Map<String, Object>) JSON.deserializeUntyped(paymentMethodDetails);
                    
                    if (!paymentMethodData.containsKey('error')) {
                        // Create Salesforce Payment_Method__c record
                        String sfPaymentMethodId = createPaymentMethodRecord(paymentMethodData);
                        
                        // Return combined response
                        Map<String, Object> combinedResponse = new Map<String, Object>{
                            'stripe_payment_method' => paymentMethodData,
                            'salesforce_payment_method_id' => sfPaymentMethodId
                        };
                        
                        return JSON.serialize(combinedResponse);
                    }
                    
                    return paymentMethodDetails;
                } else {
                    return errorJson('No payment method found in Setup Intent');
                }
            } else {
                return errorJson('Failed to retrieve Setup Intent: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('EXCEPTION in createPaymentMethodFromSetupIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to create payment method from setup intent: ' + e.getMessage());
        }
    }
    
    /**
     * Creates a Payment_Method__c record directly from Stripe payment method response
     */
    @RemoteAction
    public static String createPaymentMethodRecord(Map<String, Object> stripePaymentMethod) {
        System.debug('=== Creating Payment Method Record from Stripe Data ===');
        
        try {
            if (stripePaymentMethod == null || stripePaymentMethod.isEmpty()) {
                return errorJson('Stripe payment method data is required');
            }
            
            String stripePaymentMethodId = (String) stripePaymentMethod.get('id');
            if (String.isBlank(stripePaymentMethodId)) {
                return errorJson('Stripe payment method ID not found in response');
            }
            
            // Check if payment method already exists
            List<Payment_Method__c> existingMethods = [SELECT Id FROM Payment_Method__c WHERE Strip_Payment_ID__c = :stripePaymentMethodId LIMIT 1];
            if (!existingMethods.isEmpty()) {
                System.debug('Payment method already exists: ' + existingMethods[0].Id);
                return existingMethods[0].Id;
            }
            
            // Get account
            String accountId = null;
            List<Account> acc = [SELECT Id,Name FROM Account WHERE RecordType.DeveloperName = 'PersonAccount' ORDER BY CreatedDate DESC LIMIT 1];
            if(acc.size() > 0) {
                accountId = acc[0].Id;
            }
            
            // Create Payment_Method__c record
            Payment_Method__c pm = new Payment_Method__c(
                Strip_Payment_ID__c = stripePaymentMethodId,
                Default_Payment_Method__c = true,
                Status__c = 'Valid',
                Account__c = accountId,
                Gateway__c = 'Stripe'

            );
            
            // Get cardholder name from billing details
            String cardHolderName = '';
            Map<String, Object> billingDetails = (Map<String, Object>) stripePaymentMethod.get('billing_details');
            if (billingDetails != null) {
                cardHolderName = (String) billingDetails.get('name');
            }
            
            // Get payment type
            String paymentType = (String) stripePaymentMethod.get('type');
            
            // Populate all fields from Stripe response
            populatePaymentMethodFieldsFromStripe(pm, stripePaymentMethod, cardHolderName, paymentType);
            
            insert pm;
            
            System.debug('✅ Payment Method Record Created: ' + pm.Id);
            return pm.Id;
            
        } catch (Exception e) {
            System.debug('❌ Error creating Payment Method Record:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return errorJson('Failed to create payment method record: ' + e.getMessage());
        }
    }
    
    // Method to get payment method details from Stripe
    @RemoteAction
    public static String getStripePaymentMethodDetails(String paymentMethodId) {
        System.debug('=== Getting Stripe Payment Method Details ===');
        System.debug('Payment Method ID: ' + paymentMethodId);
        
        try {
            if (String.isBlank(paymentMethodId)) {
                return errorJson('Payment Method ID is required');
            }
            
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_methods/' + paymentMethodId;
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Payment Method Details Response Status: ' + res.getStatusCode());
            System.debug('Payment Method Details Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                return res.getBody();
            } else {
                return errorJson('Failed to retrieve payment method details: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('EXCEPTION in getStripePaymentMethodDetails:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get payment method details: ' + e.getMessage());
        }
    }
    
    // Method to create standalone Payment Method for saving cards (uses Setup Intent flow)
    @RemoteAction
    public static String createSavedPaymentMethod(String customerId, String cardholderName) {
        System.debug('=== Creating Saved Payment Method ===');
        System.debug('Customer ID: ' + customerId);
        System.debug('Cardholder Name: ' + cardholderName);
        
        try {
            // First create a Setup Intent
            String setupIntentResponse = createSetupIntent(customerId);
            
            // Parse the Setup Intent response
            Map<String, Object> setupIntentData = (Map<String, Object>) JSON.deserializeUntyped(setupIntentResponse);
            
            if (setupIntentData.containsKey('error')) {
                return setupIntentResponse; // Return the error
            }
            
            // Return the Setup Intent for frontend processing
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'setupIntent' => setupIntentData,
                'message' => 'Setup Intent created. Use client_secret on frontend to collect payment method.',
                'instructions' => 'Use Stripe.js confirmSetupIntent() with the client_secret to collect and save the payment method.'
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in createSavedPaymentMethod:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to create saved payment method: ' + e.getMessage());
        }
    }
    
    // Method to get Payment Method ID from a Payment Intent
    @RemoteAction
    public static String getPaymentMethodFromIntent(String paymentIntentId) {
        System.debug('=== Getting Payment Method from Payment Intent ===');
        System.debug('Payment Intent ID: ' + paymentIntentId);
        
        try {
            if (String.isBlank(paymentIntentId)) {
                return errorJson('Payment Intent ID is required');
            }
            
            String secretKey = getStripeSecretKey();
            HttpRequest req = new HttpRequest();
            String endpoint = BASE_URL + 'payment_intents/' + paymentIntentId;
            req.setEndpoint(endpoint);
            req.setMethod('GET');
            req.setHeader('Authorization', 'Bearer ' + secretKey);
            
            System.debug('Endpoint: ' + endpoint);
            System.debug('Method: GET');
            
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            System.debug('Response Status: ' + res.getStatusCode());
            System.debug('Response Body: ' + res.getBody());
            
            if (res.getStatusCode() == 200) {
                Map<String, Object> paymentIntent = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                
                if (paymentIntent.containsKey('payment_method')) {
                    String paymentMethodId = (String) paymentIntent.get('payment_method');
                    System.debug('✅ Found Payment Method ID: ' + paymentMethodId);
                    
                    Map<String, Object> result = new Map<String, Object>{
                        'success' => true,
                        'paymentMethodId' => paymentMethodId,
                        'paymentIntentId' => paymentIntentId
                    };
                    
                    return JSON.serialize(result);
                } else {
                    return errorJson('No payment method found for this Payment Intent');
                }
            } else {
                return errorJson('Failed to retrieve Payment Intent: ' + res.getStatus());
            }
        } catch (Exception e) {
            System.debug('EXCEPTION in getPaymentMethodFromIntent:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get payment method from intent: ' + e.getMessage());
        }
    }
    
    // Method to update invoice after successful payment and create payment records
    @RemoteAction
    public static String updateInvoiceAfterPayment(String invoiceId, String stripePaymentIntentId, Integer amountCents, String cardholderName) {
        System.debug('=== Updating Invoice After Payment ===');
        System.debug('Invoice ID: ' + invoiceId);
        System.debug('Stripe Payment Intent ID: ' + stripePaymentIntentId);
        System.debug('Amount in cents: ' + amountCents);
        System.debug('Cardholder Name: ' + cardholderName);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            if (String.isBlank(stripePaymentIntentId)) {
                return errorJson('Stripe Payment Intent ID is required');
            }
            
            if (amountCents == null || amountCents <= 0) {
                return errorJson('Valid payment amount is required');
            }
            
            // Query the custom Invoice__c object with BillingAccountId__c
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, TotalChargeAmountWithTax__c, Balance__c,
                                                Payment_Status__c, Payment_Link__c, BillingAccountId__c, CreatedDate, InvoiceDate__c
                                        FROM Invoice__c 
                                        WHERE Id = :invoiceId 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c originalInv = invoices[0];
            
            // Check if this is today's invoice or if we need to redirect to today's invoice
            Date today = Date.today();
            Date invoiceDate = originalInv.InvoiceDate__c != null ? originalInv.InvoiceDate__c : originalInv.CreatedDate.date();
            
            System.debug('Invoice Date (InvoiceDate__c): ' + originalInv.InvoiceDate__c);
            System.debug('Invoice Created Date: ' + originalInv.CreatedDate.date());
            System.debug('Using Invoice Date for comparison: ' + invoiceDate + ', Today: ' + today);
            
            Invoice__c inv = originalInv; // Use the original invoice that was requested
            
            System.debug('Processing payment for invoice: ' + inv.Name);
            System.debug('Invoice Balance: $' + inv.Balance__c);
            System.debug('Invoice Payment Status: ' + inv.Payment_Status__c);
            
            // Process the payment for the requested invoice
            // Note: We're processing the specific invoice that was requested
            
            System.debug('Current Invoice Status: ' + inv.Status__c + ' | Total: ' + inv.TotalChargeAmountWithTax__c + ' | Balance: ' + inv.Balance__c);
            
            // Convert cents to dollars
            Decimal paidAmount = amountCents / 100.0;
            System.debug('Paid Amount: $' + paidAmount);
            
            // First update the invoice status immediately for UI feedback
            inv.Payment_Status__c = 'Paid';
            inv.Status__c = 'Posted';
            inv.Balance__c = 0; 
            inv.Payment_Link__c = getVFPageURL(invoiceId);
            
            update inv;
            
            System.debug('Invoice updated successfully (immediate)');
            System.debug('New Status: ' + inv.Status__c + ' | New Balance: ' + inv.Balance__c);
            
            // Create payment method and payment records in a more resilient way
            String paymentMethodId = null;
            String paymentRecordId = null;
            
            // Create a minimal payment method record first (optimized for speed)
            try {
                System.debug('=== ATTEMPTING TO CREATE PAYMENT METHOD ===');
                System.debug('Parameters:');
                System.debug('  - stripePaymentIntentId: ' + stripePaymentIntentId);
                System.debug('  - cardholderName: ' + cardholderName);
                System.debug('  - accountId: ' + inv.BillingAccountId__c);
                
                paymentMethodId = createBasicPaymentMethod(
                    stripePaymentIntentId, // Use payment intent ID as fallback
                    String.isNotBlank(cardholderName) ? cardholderName : 'Online Payment User',
                    'Credit Card',
                    inv.BillingAccountId__c
                );
                
                System.debug('✅ Basic Payment Method created: ' + paymentMethodId);
                
            } catch (Exception pmError) {
                System.debug('❌ CRITICAL ERROR creating payment method:');
                System.debug('  - Type: ' + pmError.getTypeName());
                System.debug('  - Message: ' + pmError.getMessage());
                System.debug('  - Stack Trace: ' + pmError.getStackTraceString());
                System.debug('  - Line Number: ' + pmError.getLineNumber());
                // Continue without payment method - invoice is already updated
            }
            
            // Create Payment record
            if (String.isNotBlank(paymentMethodId)) {
                try {
                    System.debug('=== ATTEMPTING TO CREATE PAYMENT RECORD ===');
                    System.debug('Parameters:');
                    System.debug('  - invoiceId: ' + invoiceId);
                    System.debug('  - accountId: ' + inv.BillingAccountId__c);
                    System.debug('  - paymentMethodId: ' + paymentMethodId);
                    System.debug('  - paidAmount: $' + paidAmount);
                    System.debug('  - stripePaymentIntentId: ' + stripePaymentIntentId);
                    
                    paymentRecordId = createPaymentRecord(
                        invoiceId,
                        inv.BillingAccountId__c,
                        paymentMethodId,
                        paidAmount,
                        stripePaymentIntentId,
                        String.isNotBlank(cardholderName) ? cardholderName : 'Online Payment User'
                    );
                    
                    System.debug('✅ Payment record created: ' + paymentRecordId);
                    
                } catch (Exception paymentError) {
                    System.debug('❌ CRITICAL ERROR creating payment record:');
                    System.debug('  - Type: ' + paymentError.getTypeName());
                    System.debug('  - Message: ' + paymentError.getMessage());
                    System.debug('  - Stack Trace: ' + paymentError.getStackTraceString());
                    System.debug('  - Line Number: ' + paymentError.getLineNumber());
                    // Continue - invoice is already updated
                }
            } else {
                System.debug('❌ CRITICAL: Payment method ID is blank, cannot create payment record');
            }
            
            // Queue detailed payment method enrichment for later (non-blocking)
            if (String.isNotBlank(paymentMethodId)) {
                try {
                    // Try to enrich with Stripe data, but don't wait/block if it fails
                    enrichPaymentMethodAsync(paymentMethodId, stripePaymentIntentId);
                } catch (Exception enrichError) {
                    System.debug('⚠️ Could not queue payment method enrichment: ' + enrichError.getMessage());
                    // This is non-critical for the payment flow
                }
            }
            
            // Process any pending order if this payment is related to an order
            String orderId = null;
            try {
                // Query for orders related to this account that need processing
                List<Order> relatedOrders = [
                    SELECT Id, Installation_Type__c, AccountId, Status 
                    FROM Order 
                    WHERE AccountId = :inv.BillingAccountId__c
                    AND Status = 'Draft'
                    ORDER BY CreatedDate DESC
                    LIMIT 1
                ];
                
                if (!relatedOrders.isEmpty()) {
                    Order order = relatedOrders[0];
                    orderId = order.Id;
                    System.debug('Found pending order to process: ' + orderId);
                    
                    // Process the order based on installation type using the PostPaymentOrderProcessingController
                    try {
                        String orderProcessingResult = PostPaymentOrderProcessingController.processOrderAfterPayment(
                            orderId, 
                            invoiceId, 
                            stripePaymentIntentId
                        );
                        System.debug('Order processed after payment: ' + orderProcessingResult);
                    } catch (Exception orderEx) {
                        System.debug('⚠️ Error processing order after payment: ' + orderEx.getMessage());
                        // Continue with payment flow, don't block payment success due to order processing error
                    }
                } else {
                    System.debug('No pending orders found for this account');
                }
            } catch (Exception orderLookupEx) {
                System.debug('⚠️ Error looking up related order: ' + orderLookupEx.getMessage());
                // Continue with payment flow
            }
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'message' => 'Payment processed successfully! Invoice updated and payment records created.',
                'invoiceId' => inv.Id,
                'accountId' => inv.BillingAccountId__c,
                'newStatus' => inv.Status__c,
                'newBalance' => inv.Balance__c,
                'paidAmount' => paidAmount,
                'stripePaymentIntentId' => stripePaymentIntentId,
                'paymentMethodId' => paymentMethodId,
                'paymentRecordId' => paymentRecordId,
                'orderId' => orderId,
                'processingComplete' => true
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in updateInvoiceAfterPayment:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to update invoice: ' + e.getMessage());
        }
    }

    public static String getVFPageURL(String invoiceId){
        //?invoiceId=a0vgL000005KQpvQAG&accountId=001gL00000Ga4yNQAR
        PageReference pageRef = Page.paymentForm;
        
        // For Experience Sites, use Site.getBaseUrl() if available, otherwise fallback to org URL
        String baseURL;
        try {
            baseURL = Site.getBaseUrl();
            if (String.isBlank(baseURL)) {
                baseURL = System.Url.getOrgDomainUrl().toExternalForm();
            }
        } catch (Exception e) {
            baseURL = System.Url.getOrgDomainUrl().toExternalForm();
        }
        
        String accId = '';

        try{
            List<Invoice__c> parentAccountId = [SELECT BillingAccountId__c FROM Invoice__c WHERE Id =: invoiceId LIMIT 1];
            if(parentAccountId.size() > 0 && parentAccountId[0].BillingAccountId__c != null){
                accId = parentAccountId[0].BillingAccountId__c;
                System.debug('Parent Account Id: =================> ' + parentAccountId);
            }
        }catch(Exception e){
            System.debug('=====account Id in URL =======> '+ e.getMessage());
        }

        String fullURL = baseURL + pageRef.getUrl() + '?' + 'invoiceId=' + invoiceId + '&' + 'accountId=' + accId;

        return fullURL;
    }

    // Method to check if payment was completed and show thank you message
    @RemoteAction
    public static String checkPaymentCompletion(String invoiceId) {
        System.debug('=== Checking Payment Completion ===');
        System.debug('Invoice ID: ' + invoiceId);
        
        try {
            if (String.isBlank(invoiceId)) {
                return errorJson('Invoice ID is required');
            }
            
            // Query the invoice to check if it's paid
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, Payment_Status__c, 
                                                Balance__c, TotalChargeAmountWithTax__c
                                         FROM Invoice__c 
                                         WHERE Id = :invoiceId 
                                         LIMIT 1];
            
            if (invoices.isEmpty()) {
                return errorJson('Invoice not found with ID: ' + invoiceId);
            }
            
            Invoice__c inv = invoices[0];
            System.debug('Invoice Status: ' + inv.Status__c + ' | Payment Status: ' + inv.Payment_Status__c + ' | Balance: ' + inv.Balance__c);
            
            // Check if payment is completed
            Boolean isPaymentCompleted = (inv.Payment_Status__c == 'Paid' && inv.Balance__c == 0);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoiceId' => inv.Id,
                'invoiceName' => inv.Name,
                'isPaymentCompleted' => isPaymentCompleted,
                'status' => inv.Status__c,
                'paymentStatus' => inv.Payment_Status__c,
                'balance' => inv.Balance__c,
                'totalAmount' => inv.TotalChargeAmountWithTax__c
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in checkPaymentCompletion:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to check payment completion: ' + e.getMessage());
        }
    }
    
    // Method to get the first invoice with today's invoice date
    @RemoteAction
    @AuraEnabled
    public static String getTodaysFirstInvoice() {
        System.debug('=== Getting Today\'s First Invoice (by Invoice Date) ===');
        
        try {
            // Get today's date
            Date today = Date.today();
            System.debug('Looking for invoices with invoice date: ' + today);
            
            // Query for invoices with today's invoice date, ordered by creation time
            List<Invoice__c> todaysInvoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                                       BillingAccountId__r.Name, Balance__c, 
                                                       TotalChargeAmountWithTax__c, CreatedDate, InvoiceDate__c
                                                FROM Invoice__c 
                                                WHERE InvoiceDate__c = :today
                                                AND Balance__c > 0
                                                ORDER BY CreatedDate ASC 
                                                LIMIT 1];
            
            if (todaysInvoices.isEmpty()) {
                System.debug('No invoices found with today\'s invoice date and outstanding balance');
                return errorJson('No unpaid invoices found with today\'s invoice date');
            }
            
            Invoice__c firstInvoice = todaysInvoices[0];
            System.debug('First invoice found: ' + firstInvoice.Name + ' | Balance: $' + firstInvoice.Balance__c);
            
            // Generate the payment URL for this invoice
            String paymentUrl = getVFPageURL(firstInvoice.Id);
            System.debug('Payment URL generated: ' + paymentUrl);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => new Map<String, Object>{
                    'id' => firstInvoice.Id,
                    'name' => firstInvoice.Name,
                    'status' => firstInvoice.Status__c,
                    'balance' => firstInvoice.Balance__c,
                    'totalAmount' => firstInvoice.TotalChargeAmountWithTax__c,
                    'accountId' => firstInvoice.BillingAccountId__c,
                    'accountName' => firstInvoice.BillingAccountId__r?.Name,
                    'createdDate' => firstInvoice.CreatedDate
                },
                'paymentUrl' => paymentUrl,
                'message' => 'Found today\'s first invoice: ' + firstInvoice.Name
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getTodaysFirstInvoice:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get today\'s first invoice: ' + e.getMessage());
        }
    }
    
    @RemoteAction
    public static String validateInvoiceAccountRelationship(String invoiceId,String accountId){
        System.debug('========VALIDATE INVOICE AND ACCOUNT RELATIONSHIP===========');
        System.debug('Account id ===> ' + accountId);
        System.debug('Invoice id ===> ' + invoiceId);

        try {
            if(String.isBlank(invoiceId))return errorJson('Invoice Id is Required....');
            if(String.isBlank(accountId))return errorJson('Account Id is Required....');

            List<Invoice__c> invoices = [SELECT Id,Name,BillingAccountId__c, BillingAccountId__r.Name FROM Invoice__c  WHERE Id =: invoiceId AND BillingAccountId__c =: accountId LIMIT 1];
            if(invoices.isEmpty()){
                System.debug('===Invoice exists but belongs to different Person Account :======== ');

                List<Invoice__c> invoiceExists=[SELECT Id,BillingAccountId__c,BillingAccountId__r.Name FROM Invoice__c WHERE Id =: invoiceId Limit 1];
                if(invoiceExists.isEmpty())return errorJson('Invoice Id Not Found with Id : '+ invoiceId);
                else{
                    String actualName = invoiceExists[0].BillingAccountId__r?.Name;
                    return errorJson('Invoice does not belong to the specified account. This invoice belongs to: '+ actualName);
                }
            }

            Invoice__c inv = invoices[0];
            System.debug('====Invoice found and belongs to correct account=====');
            System.debug(invoices);
            System.debug('Validation successful: Invoice ' + inv.Name + ' belongs to account ' + inv.BillingAccountId__r.Name);

            Map<String,Object> result = new Map<String,object>{
                'success' => true,
                'message' => 'Invoice belongs to the specified account',
                'invoiceId' => inv.Id,
                'invoiceName' => inv.Name,
                'accountId' => inv.BillingAccountId__c,
                'accountName' => inv.BillingAccountId__r.Name
            };
            System.debug('============= result object =====================');
            System.debug(result);
            return JSON.serialize(result);
        } catch (Exception e) {
            System.debug('EXCEPTION in validateInvoiceAccountRelationship:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to validate invoice-account relationship: ' + e.getMessage());
        }
    }


    private static String createPaymentMethod(String stripePaymentMethodId, String cardHolderName, String paymentType, String stripePaymentIntentId){
        System.debug('====== CREATING PAYMENT METHOD ============');
        System.debug('Stripe Payment Method ID: ' + stripePaymentMethodId);
        System.debug('Stripe Payment Intent ID: ' + stripePaymentIntentId);
        System.debug('Cardholder Name: ' + cardHolderName);
        System.debug('Payment Type: ' + paymentType);

        try {
            // Get the account ID from the payment context
            String accountId = null;
            List<Account> acc = [SELECT Id,Name FROM Account WHERE RecordType.DeveloperName = 'PersonAccount' ORDER BY CreatedDate DESC LIMIT 1];
            
            if(acc.size() > 0) {
                accountId = acc[0].Id;
                System.debug('Using Account ID: ' + accountId + ' (' + acc[0].Name + ')');
            }
            
            // Create Payment_Method__c record with basic information first
            Payment_Method__c pm = new Payment_Method__c(
                Strip_Payment_ID__c = stripePaymentMethodId,
                Default_Payment_Method__c = true,
                Status__c = 'Valid',
                Account__c = accountId,
                Gateway__c = 'Stripe',
                Payment_Type__c = String.isNotBlank(paymentType) ? paymentType : 'Credit Card',
                Currency__c = 'USD'
            );
            
            // Set cardholder name fields if available
            if (String.isNotBlank(cardHolderName)) {
                pm.Name_On_Card__c = cardHolderName;
                
                // Split name into first and last
                List<String> nameParts = cardHolderName.trim().split(' ');
                if (nameParts.size() >= 1) {
                    pm.First_Name__c = nameParts[0];
                    if (nameParts.size() > 1) {
                        List<String> lastNameParts = new List<String>();
                        for (Integer i = 1; i < nameParts.size(); i++) {
                            lastNameParts.add(nameParts[i]);
                        }
                        pm.Last_Name__c = String.join(lastNameParts, ' ');
                    }
                }
            }
            
            // Try to get detailed information from Stripe in background (non-blocking)
            try {
                String stripePaymentMethodDetails = getStripePaymentMethodDetails(stripePaymentMethodId);
                Map<String, Object> paymentMethodData = (Map<String, Object>) JSON.deserializeUntyped(stripePaymentMethodDetails);
                
                // Only populate additional fields if we get a successful response
                if (!paymentMethodData.containsKey('error')) {
                    System.debug('✅ Got Stripe payment method details, populating additional fields...');
                    populatePaymentMethodFieldsFromStripe(pm, paymentMethodData, cardHolderName, paymentType);
                } else {
                    System.debug('⚠️ Could not get Stripe payment method details, using basic info only');
                }
            } catch (Exception stripeDetailException) {
                System.debug('⚠️ Error getting Stripe payment method details (non-critical): ' + stripeDetailException.getMessage());
                // Continue with basic payment method record - this is not critical for payment processing
            }
            
            insert pm;

            System.debug('✅ PAYMENT METHOD CREATED SUCCESSFULLY: ' + pm.Id);
            System.debug('   - Stripe Payment Method ID: ' + stripePaymentMethodId);
            System.debug('   - Cardholder: ' + cardHolderName);
            System.debug('   - Account: ' + accountId);

            return pm.Id;

        } catch (Exception e) {
            System.debug('❌ Error creating Payment Method:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            throw e;
        }   
    }
    
    /**
     * Helper method to populate Payment_Method__c fields from Stripe payment method response
     */
    private static void populatePaymentMethodFieldsFromStripe(Payment_Method__c pm, Map<String, Object> stripePaymentMethod, String cardHolderName, String paymentType) {
        // Get the Stripe payment method ID for reference
        String stripePaymentMethodId = (String) stripePaymentMethod.get('id');
        System.debug('====== POPULATING PAYMENT METHOD FIELDS FROM STRIPE ============');
        System.debug('Stripe Payment Method Data: ' + JSON.serializePretty(stripePaymentMethod));
        
        try {
            // Set basic payment method type
            String pmType = (String) stripePaymentMethod.get('type');
            if (String.isNotBlank(pmType)) {
                if (pmType.equalsIgnoreCase('card')) {
                    pm.Payment_Type__c = 'Credit Card';
                } else if (pmType.equalsIgnoreCase('us_bank_account')) {
                    pm.Payment_Type__c = 'ACH';
                } else {
                    pm.Payment_Type__c = String.isNotBlank(paymentType) ? paymentType : 'Credit Card';
                }
            }
            
            // Handle card-specific data
            Map<String, Object> cardData = (Map<String, Object>) stripePaymentMethod.get('card');
            if (cardData != null) {
                System.debug('Processing card data: ' + JSON.serializePretty(cardData));
                
                // Card brand/type
                String brand = (String) cardData.get('brand');
                if (String.isNotBlank(brand)) {
                    if (brand.equalsIgnoreCase('visa')) {
                        pm.Card__c = 'Visa';
                    } else if (brand.equalsIgnoreCase('mastercard')) {
                        pm.Card__c = 'Master Card';
                    } else {
                        // For other brands, you might want to add more options to your picklist
                        pm.Card__c = 'Visa'; // Default fallback
                    }
                }
                
                // Card last 4 digits
                String last4 = (String) cardData.get('last4');
                if (String.isNotBlank(last4)) {
                    pm.Card_Last_4_Digit__c = last4;
                    
                    // Create masked card number in format **** **** **** 1234
                    pm.Card_Number__c = '**** **** **** ' + last4;
                    System.debug('✅ Masked card number created: **** **** **** ' + last4);
                }
                
                // Card expiration month
                Object expMonth = cardData.get('exp_month');
                if (expMonth != null) {
                    String monthStr = String.valueOf(expMonth);
                    if (monthStr.length() == 1) {
                        monthStr = '0' + monthStr; // Pad single digit months
                    }
                    pm.Card_Expire_Month__c = monthStr;
                }
                
                // Card expiration year
                Object expYear = cardData.get('exp_year');
                if (expYear != null) {
                    pm.Card_Expire_Year__c = String.valueOf(expYear);
                }
                
                // Funding type (credit/debit)
                String funding = (String) cardData.get('funding');
                if (String.isNotBlank(funding)) {
                    if (funding.equalsIgnoreCase('credit')) {
                        pm.Funding__c = 'Credit';
                    } else if (funding.equalsIgnoreCase('debit')) {
                        pm.Funding__c = 'Debit';
                    }
                }
                
                // Fingerprint (for duplicate detection)
                String fingerprint = (String) cardData.get('fingerprint');
                if (String.isNotBlank(fingerprint)) {
                    pm.Finger_Print_Length__c = String.valueOf(fingerprint.length());
                }
            }
            
            // Handle US Bank Account data
            Map<String, Object> bankAccountData = (Map<String, Object>) stripePaymentMethod.get('us_bank_account');
            if (bankAccountData != null) {
                System.debug('Processing bank account data: ' + JSON.serializePretty(bankAccountData));
                
                // Bank account type
                String accountType = (String) bankAccountData.get('account_type');
                if (String.isNotBlank(accountType)) {
                    pm.Bank_Account_Type__c = accountType.toLowerCase().contains('checking') ? 'Checking' : 'Savings';
                }
                
                // Bank account holder type
                String accountHolderType = (String) bankAccountData.get('account_holder_type');
                if (String.isNotBlank(accountHolderType)) {
                    pm.Account_Holder_Type__c = accountHolderType;
                }
                
                // Bank name
                String bankName = (String) bankAccountData.get('bank_name');
                if (String.isNotBlank(bankName)) {
                    pm.Bank_Name__c = bankName;
                }
                
                // Last 4 digits of account
                String last4 = (String) bankAccountData.get('last4');
                if (String.isNotBlank(last4)) {
                    pm.Bank_Account_Number__c = last4; // Store only last 4 for security
                }
                
                // Routing number (if available)
                String routingNumber = (String) bankAccountData.get('routing_number');
                if (String.isNotBlank(routingNumber)) {
                    pm.Bank_Routing_Code__c = routingNumber;
                }
            }
            
            // Billing details
            Map<String, Object> billingDetails = (Map<String, Object>) stripePaymentMethod.get('billing_details');
            if (billingDetails != null) {
                System.debug('Processing billing details: ' + JSON.serializePretty(billingDetails));
                
                // Cardholder name from billing details (preferred over parameter)
                String billingName = (String) billingDetails.get('name');
                if (String.isNotBlank(billingName)) {
                    cardHolderName = billingName;
                }
                
                // Email
                String email = (String) billingDetails.get('email');
                if (String.isNotBlank(email)) {
                    pm.Email__c = email;
                }
            }
            
            // Set cardholder name fields
            if (String.isNotBlank(cardHolderName)) {
                pm.Name_On_Card__c = cardHolderName;
                
                // Split name into first and last
                List<String> nameParts = cardHolderName.trim().split(' ');
                if (nameParts.size() >= 1) {
                    pm.First_Name__c = nameParts[0];
                    if (nameParts.size() > 1) {
                        List<String> lastNameParts = new List<String>();
                        for (Integer i = 1; i < nameParts.size(); i++) {
                            lastNameParts.add(nameParts[i]);
                        }
                        pm.Last_Name__c = String.join(lastNameParts, ' ');
                    }
                }
            }
            
            // Set currency (default to USD if not specified)
            pm.Currency__c = 'USD'; // Stripe supports multiple currencies, but defaulting to USD
            
            // Store the full Stripe response for debugging/reference (truncated due to field length)
            String responseJson = JSON.serialize(stripePaymentMethod);
            if (responseJson.length() <= 18) { 
                pm.Gateway_Response__c = responseJson;
            } else {
                // Store just the payment method ID due to field length constraint
                if (String.isNotBlank(stripePaymentMethodId)) {
                    pm.Gateway_Response__c = stripePaymentMethodId.length() <= 18 ? stripePaymentMethodId : stripePaymentMethodId.left(18);
                }
            }
            
            System.debug('✅ Payment Method fields populated from Stripe response');
            
        } catch (Exception e) {
            System.debug('❌ Error populating fields from Stripe response: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            // Don't throw exception, just continue with basic data
        }
    }



    private static String createPaymentRecord(String invoiceId,String accountId,String paymentMethodId,Decimal amount,String stripePaymentIntentId,String paidByName){
        System.debug('========= CREATING PAYMENT RECORD ================');
        System.debug('Invoice Id =====> ' + invoiceId);
        System.debug('Account Id =======> ' + accountId);
        System.debug('Payment method Id =======>' + paymentMethodId);
        System.debug('Amount ===>' + amount);
        System.debug('Stripe Payment Intent Id =============> ' + stripePaymentIntentId);
        System.debug('Paid by mee =============> ' + paidByName);


        try{

            Payment__c payment = new Payment__c(
                Name = 'Payment - ' + stripePaymentIntentId,
                Invoice__c = invoiceId,
                Account__c = accountId,
                Payment_Method__c = paymentMethodId,
                Status__c = 'Posted',
                Balance__c = amount
            );

            insert payment;
            System.debug('=========== Payment Created ==================== '+ payment.Id);
            return payment.Id;


        }catch(Exception e){
            System.debug(' Error creating Payment record:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            throw e;
        }

    }
    
    // Method to get account associated with a user ID
    @AuraEnabled(cacheable=true)
    public static String getAccountByUserId(String userId) {
        System.debug('=== Getting Account for User ID ===');
        System.debug('User ID: ' + userId);
        
        try {
            if (String.isBlank(userId)) {
                return errorJson('User ID is required');
            }
            
            // Query user and their account relationships
            List<User> users = [SELECT Id, Name, Email, ContactId, Contact.AccountId,
                                    AccountId, Account.Id, Account.Name
                                FROM User 
                                WHERE Id = :userId 
                                LIMIT 1];
            
            if (users.isEmpty()) {
                return errorJson('User not found with ID: ' + userId);
            }
            
            User user = users[0];
            String accountId = null;
            String accountName = null;
            
            // Try multiple ways to get the account
            if (user.AccountId != null) {
                // Direct account relationship
                accountId = user.AccountId;
                accountName = user.Account?.Name;
                System.debug('Found account via direct AccountId: ' + accountId);
            } else if (user.ContactId != null && user.Contact.AccountId != null) {
                // Account through contact relationship
                accountId = user.Contact.AccountId;
                System.debug('Found account via Contact.AccountId: ' + accountId);
                
                // Get account name separately if needed
                if (accountName == null) {
                    List<Account> accounts = [SELECT Id, Name FROM Account WHERE Id = :accountId LIMIT 1];
                    if (!accounts.isEmpty()) {
                        accountName = accounts[0].Name;
                    }
                }
            }
            
            if (String.isBlank(accountId)) {
                return errorJson('No account found associated with user: ' + user.Name);
            }
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'accountId' => accountId,
                'accountName' => accountName,
                'userId' => user.Id,
                'userName' => user.Name,
                'userEmail' => user.Email
            };

            
            System.debug('Account found for user: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getAccountByUserId:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get account for user: ' + e.getMessage());
        }
    }
    
    // Method to get current user's invoice (for debugging)
    @RemoteAction
    @AuraEnabled
    public static String getCurrentUserInvoice() {
        System.debug('=== Getting Current User Invoice ===');
        
        try {
            String userId = UserInfo.getUserId();
            System.debug('Current User ID: ' + userId);
            
            // Get current user's account
            List<User> users = [SELECT Id, ContactId, Contact.AccountId, AccountId 
                               FROM User 
                               WHERE Id = :userId 
                               LIMIT 1];
            
            String currentUserAccountId = null;
            if (!users.isEmpty()) {
                User currentUser = users[0];
                if (currentUser.AccountId != null) {
                    currentUserAccountId = currentUser.AccountId;
                    System.debug('Found AccountId directly: ' + currentUserAccountId);
                } else if (currentUser.ContactId != null && currentUser.Contact.AccountId != null) {
                    currentUserAccountId = currentUser.Contact.AccountId;
                    System.debug('Found AccountId via Contact: ' + currentUserAccountId);
                }
            }
            
            if (String.isBlank(currentUserAccountId)) {
                return errorJson('No account found for current user');
            }
            
            // Get account name
            Account userAccount = [SELECT Id, Name FROM Account WHERE Id = :currentUserAccountId LIMIT 1];
            System.debug('User Account: ' + userAccount.Name);
            
            // Get latest invoice for this account
            List<Invoice__c> userInvoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, Balance__c, 
                                            TotalChargeAmountWithTax__c, CreatedDate
                                      FROM Invoice__c 
                                      WHERE BillingAccountId__c = :currentUserAccountId
                                      AND Balance__c > 0
                                      ORDER BY CreatedDate DESC 
                                      LIMIT 1];
            
            if (userInvoices.isEmpty()) {
                return errorJson('No invoices found for your account: ' + userAccount.Name);
            }
            
            Invoice__c userInvoice = userInvoices[0];
            System.debug('Found user invoice: ' + userInvoice.Name + ' for account: ' + userInvoice.BillingAccountId__r.Name);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => new Map<String, Object>{
                    'id' => userInvoice.Id,
                    'name' => userInvoice.Name,
                    'status' => userInvoice.Status__c,
                    'balance' => userInvoice.Balance__c,
                    'totalAmount' => userInvoice.TotalChargeAmountWithTax__c,
                    'accountId' => userInvoice.BillingAccountId__c,
                    'accountName' => userInvoice.BillingAccountId__r?.Name,
                    'createdDate' => userInvoice.CreatedDate
                },
                'message' => 'Found invoice for your account: ' + userAccount.Name
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getCurrentUserInvoice:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get current user invoice: ' + e.getMessage());
        }
    }
    
    // Method to get the most recently created account's latest invoice (from userDetail component)
    @RemoteAction
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceFromRecentAccount() {
        System.debug('=== Getting Latest Invoice from Most Recent Account ===');
        
        try {
            // Find the most recently created Person Account (created by userDetail component)
            List<Account> recentAccounts = [SELECT Id, Name, CreatedDate 
                                          FROM Account 
                                          WHERE RecordType.DeveloperName = 'PersonAccount'
                                          ORDER BY CreatedDate DESC 
                                          LIMIT 5]; // Get top 5 recent accounts
            
            if (recentAccounts.isEmpty()) {
                System.debug('No Person Accounts found');
                return errorJson('No Person Accounts found in the system');
            }
            
            System.debug('Found ' + recentAccounts.size() + ' recent Person Accounts');
            
            // Try to find an unpaid invoice from the most recent accounts
            for (Account account : recentAccounts) {
                System.debug('Checking account: ' + account.Name + ' (ID: ' + account.Id + ', Created: ' + account.CreatedDate + ')');
                
                // Check if this account has unpaid invoices
                List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                                BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                                Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                                Payment_Status__c
                                            FROM Invoice__c 
                                            WHERE BillingAccountId__c = :account.Id
                                                AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                                AND Balance__c > 0
                                            ORDER BY CreatedDate DESC 
                                            LIMIT 1];
                
                if (!invoices.isEmpty()) {
                    Invoice__c invoice = invoices[0];
                    System.debug('Found unpaid invoice for account ' + account.Name + ': ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
                    
                    Map<String, Object> invoiceData = new Map<String, Object>{
                        'Id' => invoice.Id,
                        'Name' => invoice.Name,
                        'Status__c' => invoice.Status__c,
                        'AccountId' => invoice.BillingAccountId__c,
                        'AccountName' => invoice.BillingAccountId__r?.Name,
                        'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                        'Balance' => invoice.Balance__c,
                        'CreatedDate' => invoice.CreatedDate,
                        'DueDate' => invoice.DueDate__c,
                        'InvoiceDate' => invoice.InvoiceDate__c,
                        'PaymentStatus' => invoice.Payment_Status__c
                    };
                    
                    Map<String, Object> result = new Map<String, Object>{
                        'success' => true,
                        'invoice' => invoiceData,
                        'message' => 'Latest invoice found from recent account: ' + account.Name
                    };
                    
                    System.debug('Latest invoice from recent account: ' + JSON.serialize(result));
                    return JSON.serialize(result);
                }
            }
            
            System.debug('No unpaid invoices found in recent accounts');
            return errorJson('No unpaid invoices found in recently created accounts');
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceFromRecentAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice from recent account: ' + e.getMessage());
        }
    }
    
    // Method to get latest unpaid invoice by account name (useful for finding newly created accounts)
    @RemoteAction
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceForAccountByName(String accountName) {
        System.debug('=== Getting Latest Invoice for Account by Name ===');
        System.debug('Account Name: ' + accountName);
        
        try {
            if (String.isBlank(accountName)) {
                return errorJson('Account name is required');
            }
            
            // First find the most recent account with this name
            List<Account> accounts = [SELECT Id, Name FROM Account 
                                     WHERE Name = :accountName 
                                     ORDER BY CreatedDate DESC 
                                     LIMIT 1];
            
            if (accounts.isEmpty()) {
                System.debug('No account found with name: ' + accountName);
                return errorJson('No account found with name: ' + accountName);
            }
            
            Account account = accounts[0];
            System.debug('Found account: ' + account.Id + ' - ' + account.Name);
            
            // Now get the latest unpaid invoice for this account
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                            Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                            Payment_Status__c
                                        FROM Invoice__c 
                                        WHERE BillingAccountId__c = :account.Id
                                            AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                            AND Balance__c > 0
                                        ORDER BY CreatedDate DESC 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                System.debug('No unpaid invoices found for account: ' + account.Name);
                return errorJson('No unpaid invoices found for account: ' + account.Name);
            }
            
            Invoice__c invoice = invoices[0];
            System.debug('Found latest invoice: ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'Id' => invoice.Id,
                'Name' => invoice.Name,
                'Status__c' => invoice.Status__c,
                'AccountId' => invoice.BillingAccountId__c,
                'AccountName' => invoice.BillingAccountId__r?.Name,
                'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                'Balance' => invoice.Balance__c,
                'CreatedDate' => invoice.CreatedDate,
                'DueDate' => invoice.DueDate__c,
                'InvoiceDate' => invoice.InvoiceDate__c,
                'PaymentStatus' => invoice.Payment_Status__c
            };
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => invoiceData,
                'message' => 'Latest invoice found for account: ' + account.Name
            };
            
            System.debug('Invoice found by account name: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceForAccountByName:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get invoice for account name: ' + e.getMessage());
        }
    }
    
    // Method to get latest unpaid invoice for a specific account
    @AuraEnabled(cacheable=false)
    public static String getLatestInvoiceForAccount(String accountId) {
        System.debug('=== Getting Latest Invoice for Account ===');
        System.debug('Account ID: ' + accountId);
        
        try {
            if (String.isBlank(accountId)) {
                return errorJson('Account ID is required');
            }
            
            // Query for the latest unpaid invoice for this account
            List<Invoice__c> invoices = [SELECT Id, Name, Status__c, BillingAccountId__c, 
                                            BillingAccountId__r.Name, TotalChargeAmountWithTax__c, 
                                            Balance__c, CreatedDate, DueDate__c, InvoiceDate__c,
                                            Payment_Status__c
                                        FROM Invoice__c 
                                        WHERE BillingAccountId__c = :accountId
                                            AND (Payment_Status__c = 'Unpaid' OR Payment_Status__c = null)
                                            AND Balance__c > 0
                                        ORDER BY CreatedDate DESC 
                                        LIMIT 1];
            
            if (invoices.isEmpty()) {
                System.debug('No unpaid invoices found for account: ' + accountId);
                return errorJson('No unpaid invoices found for this account.');
            }
            
            Invoice__c invoice = invoices[0];
            System.debug('Found latest invoice: ' + invoice.Name + ' | Balance: $' + invoice.Balance__c);
            
            Map<String, Object> invoiceData = new Map<String, Object>{
                'Id' => invoice.Id,
                'Name' => invoice.Name,
                'Status__c' => invoice.Status__c,
                'AccountId' => invoice.BillingAccountId__c,
                'AccountName' => invoice.BillingAccountId__r?.Name,
                'TotalAmount' => invoice.TotalChargeAmountWithTax__c,
                'Balance' => invoice.Balance__c,
                'CreatedDate' => invoice.CreatedDate,
                'DueDate' => invoice.DueDate__c,
                'InvoiceDate' => invoice.InvoiceDate__c,
                'PaymentStatus' => invoice.Payment_Status__c
            };
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'invoice' => invoiceData,
                'message' => 'Latest invoice found successfully'
            };
            
            System.debug('Latest invoice result: ' + JSON.serialize(result));
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('EXCEPTION in getLatestInvoiceForAccount:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            System.debug('  - Line Number: ' + e.getLineNumber());
            return errorJson('Failed to get latest invoice for account: ' + e.getMessage());
        }
    }
    
    /**
     * Method to update an existing Payment_Method__c record with data from Stripe
     * This can be called when you already have a Payment_Method__c record but want to populate it with Stripe data
     */
    @RemoteAction
    public static String updatePaymentMethodWithStripeData(String salesforcePaymentMethodId, String stripePaymentMethodId) {
        System.debug('=== Updating Payment Method with Stripe Data ===');
        System.debug('Salesforce Payment Method ID: ' + salesforcePaymentMethodId);
        System.debug('Stripe Payment Method ID: ' + stripePaymentMethodId);
        
        try {
            if (String.isBlank(salesforcePaymentMethodId)) {
                return errorJson('Salesforce Payment Method ID is required');
            }
            
            if (String.isBlank(stripePaymentMethodId)) {
                return errorJson('Stripe Payment Method ID is required');
            }
            
            // Get the existing Payment_Method__c record
            List<Payment_Method__c> existingMethods = [SELECT Id, Strip_Payment_ID__c, Payment_Type__c, 
                                                              First_Name__c, Last_Name__c, Name_On_Card__c,
                                                              Account__c, Gateway__c, Status__c
                                                       FROM Payment_Method__c 
                                                       WHERE Id = :salesforcePaymentMethodId 
                                                       LIMIT 1];
            
            if (existingMethods.isEmpty()) {
                return errorJson('Payment Method record not found with ID: ' + salesforcePaymentMethodId);
            }
            
            Payment_Method__c pm = existingMethods[0];
            System.debug('Found existing Payment Method record: ' + pm.Id);
            
            // Get Stripe payment method details
            String stripePaymentMethodDetails = getStripePaymentMethodDetails(stripePaymentMethodId);
            Map<String, Object> paymentMethodData = (Map<String, Object>) JSON.deserializeUntyped(stripePaymentMethodDetails);
            
            if (paymentMethodData.containsKey('error')) {
                System.debug('❌ Error getting Stripe payment method details: ' + paymentMethodData.get('error'));
                return errorJson('Failed to retrieve Stripe payment method details: ' + paymentMethodData.get('message'));
            }
            
            // Update the Stripe Payment ID if not already set
            if (String.isBlank(pm.Strip_Payment_ID__c)) {
                pm.Strip_Payment_ID__c = stripePaymentMethodId;
            }
            
            // Set gateway if not already set
            if (String.isBlank(pm.Gateway__c)) {
                pm.Gateway__c = 'Stripe';
            }
            
            // Get cardholder name from existing record or billing details
            String cardHolderName = pm.Name_On_Card__c;
            if (String.isBlank(cardHolderName)) {
                Map<String, Object> billingDetails = (Map<String, Object>) paymentMethodData.get('billing_details');
                if (billingDetails != null) {
                    cardHolderName = (String) billingDetails.get('name');
                }
            }
            
            // Get payment type from existing record or Stripe data
            String paymentType = pm.Payment_Type__c;
            if (String.isBlank(paymentType)) {
                String pmType = (String) paymentMethodData.get('type');
                if ('card'.equalsIgnoreCase(pmType)) {
                    paymentType = 'Credit Card';
                } else if ('us_bank_account'.equalsIgnoreCase(pmType)) {
                    paymentType = 'ACH';
                } else {
                    paymentType = 'Credit Card';
                }
            }
            
            // Populate all fields from Stripe response
            populatePaymentMethodFieldsFromStripe(pm, paymentMethodData, cardHolderName, paymentType);
            
            // Update the record
            update pm;
            
            System.debug('✅ Payment Method updated successfully: ' + pm.Id);
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'message' => 'Payment Method updated with Stripe data successfully',
                'salesforcePaymentMethodId' => pm.Id,
                'stripePaymentMethodId' => stripePaymentMethodId
            };
            
            return JSON.serialize(result);
            
        } catch (Exception e) {
            System.debug('❌ Error updating Payment Method with Stripe data:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return errorJson('Failed to update payment method with Stripe data: ' + e.getMessage());
        }
    }
    
    /**
     * Creates a basic payment method record quickly without external API calls
     * This is optimized for speed during payment processing
     */
    private static String createBasicPaymentMethod(String stripePaymentMethodId, String cardHolderName, String paymentType, String accountId) {
        System.debug('====== CREATING BASIC PAYMENT METHOD (OPTIMIZED) ============');
        System.debug('Stripe Payment Method ID: ' + stripePaymentMethodId);
        System.debug('Cardholder Name: ' + cardHolderName);
        System.debug('Payment Type: ' + paymentType);
        System.debug('Account ID: ' + accountId);

        try {
            // If no account provided, get the most recent one
            if (String.isBlank(accountId)) {
                List<Account> acc = [SELECT Id,Name FROM Account WHERE RecordType.DeveloperName = 'PersonAccount' ORDER BY CreatedDate DESC LIMIT 1];
                if(acc.size() > 0) {
                    accountId = acc[0].Id;
                    System.debug('Using Account ID: ' + accountId + ' (' + acc[0].Name + ')');
                }
            }
            
            // Create basic Payment_Method__c record (no external API calls)
            Payment_Method__c pm = new Payment_Method__c(
                Strip_Payment_ID__c = stripePaymentMethodId,
                Default_Payment_Method__c = true,
                Status__c = 'Valid',
                Account__c = accountId,
                Gateway__c = 'Stripe',
                Payment_Type__c = String.isNotBlank(paymentType) ? paymentType : 'Credit Card',
                Currency__c = 'USD'
            );
            
            // Set cardholder name fields if available
            if (String.isNotBlank(cardHolderName)) {
                pm.Name_On_Card__c = cardHolderName;
                
                // Split name into first and last
                List<String> nameParts = cardHolderName.trim().split(' ');
                if (nameParts.size() >= 1) {
                    pm.First_Name__c = nameParts[0];
                    if (nameParts.size() > 1) {
                        List<String> lastNameParts = new List<String>();
                        for (Integer i = 1; i < nameParts.size(); i++) {
                            lastNameParts.add(nameParts[i]);
                        }
                        pm.Last_Name__c = String.join(lastNameParts, ' ');
                    }
                }
            }
            
            // Set a placeholder masked card number (will be updated with actual last 4 during enrichment)
            pm.Card_Number__c = '**** **** **** ****';
            System.debug('✅ Placeholder masked card number set (will be enriched with actual last 4 digits later)');
            
            
            insert pm;

            System.debug('✅ BASIC PAYMENT METHOD CREATED: ' + pm.Id);
            return pm.Id;

        } catch (Exception e) {
            System.debug('❌ Error creating basic Payment Method:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            throw e;
        }   
    }
    
    /**
     * Queues enrichment of payment method with Stripe data for background processing
     * This method doesn't block the payment flow
     */
    @future(callout=true)
    public static void enrichPaymentMethodAsync(String paymentMethodId, String stripePaymentIntentId) {
        System.debug('====== ENRICHING PAYMENT METHOD ASYNC ============');
        System.debug('Payment Method ID: ' + paymentMethodId);
        System.debug('Stripe Payment Intent ID: ' + stripePaymentIntentId);
        
        try {
            // Get the existing payment method
            List<Payment_Method__c> existingMethods = [SELECT Id, Strip_Payment_ID__c, Name_On_Card__c, Payment_Type__c 
                                                      FROM Payment_Method__c 
                                                      WHERE Id = :paymentMethodId 
                                                      LIMIT 1];
            
            if (existingMethods.isEmpty()) {
                System.debug('Payment method not found for enrichment: ' + paymentMethodId);
                return;
            }
            
            Payment_Method__c pm = existingMethods[0];
            
            // Try to get the actual Payment Method ID from the Payment Intent
            String actualStripePaymentMethodId = pm.Strip_Payment_ID__c;
            
            try {
                String paymentMethodResult = getPaymentMethodFromIntent(stripePaymentIntentId);
                Map<String, Object> pmResult = (Map<String, Object>) JSON.deserializeUntyped(paymentMethodResult);
                
                if (pmResult.get('success') == true) {
                    actualStripePaymentMethodId = (String) pmResult.get('paymentMethodId');
                    System.debug('✅ Retrieved actual Payment Method ID for enrichment: ' + actualStripePaymentMethodId);
                    
                    // Update the Stripe Payment ID if different
                    if (pm.Strip_Payment_ID__c != actualStripePaymentMethodId) {
                        pm.Strip_Payment_ID__c = actualStripePaymentMethodId;
                    }
                }
            } catch (Exception pmEx) {
                System.debug('⚠️ Could not get Payment Method ID from Intent, using existing ID');
            }
            
            // Try to get detailed information from Stripe
            try {
                String stripePaymentMethodDetails = getStripePaymentMethodDetails(actualStripePaymentMethodId);
                Map<String, Object> paymentMethodData = (Map<String, Object>) JSON.deserializeUntyped(stripePaymentMethodDetails);
                
                // Only populate additional fields if we get a successful response
                if (!paymentMethodData.containsKey('error')) {
                    System.debug('✅ Got Stripe payment method details for enrichment, populating fields...');
                    populatePaymentMethodFieldsFromStripe(pm, paymentMethodData, pm.Name_On_Card__c, pm.Payment_Type__c);
                    
                    update pm;
                    System.debug('✅ Payment method enriched successfully');
                } else {
                    System.debug('⚠️ Could not get Stripe payment method details for enrichment');
                }
            } catch (Exception stripeDetailException) {
                System.debug('⚠️ Error getting Stripe payment method details for enrichment: ' + stripeDetailException.getMessage());
            }
            
        } catch (Exception e) {
            System.debug('❌ Error enriching payment method:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            // Don't throw exception - this is background processing
        }
    }
    
    /**
     * Utility method to test Stripe payment method data extraction
     * This method can be used for testing to see what data comes from Stripe
     */
    @RemoteAction
    public static String testStripePaymentMethodDataExtraction(String stripePaymentMethodId) {
        System.debug('=== Testing Stripe Payment Method Data Extraction ===');
        System.debug('Stripe Payment Method ID: ' + stripePaymentMethodId);
        
        try {
            if (String.isBlank(stripePaymentMethodId)) {
                return errorJson('Stripe Payment Method ID is required');
            }
            
            // Get Stripe payment method details
            String stripePaymentMethodDetails = getStripePaymentMethodDetails(stripePaymentMethodId);
            Map<String, Object> paymentMethodData = (Map<String, Object>) JSON.deserializeUntyped(stripePaymentMethodDetails);
            
            if (paymentMethodData.containsKey('error')) {
                return errorJson('Failed to retrieve Stripe payment method: ' + paymentMethodData.get('message'));
            }
            
            // Extract and map all available fields
            Map<String, Object> extractedData = new Map<String, Object>();
            
            // Basic payment method info
            extractedData.put('stripe_id', paymentMethodData.get('id'));
            extractedData.put('type', paymentMethodData.get('type'));
            extractedData.put('created', paymentMethodData.get('created'));
            extractedData.put('livemode', paymentMethodData.get('livemode'));
            
            // Card data
            Map<String, Object> cardData = (Map<String, Object>) paymentMethodData.get('card');
            if (cardData != null) {
                Map<String, Object> cardFields = new Map<String, Object>();
                cardFields.put('brand', cardData.get('brand'));
                cardFields.put('country', cardData.get('country'));
                cardFields.put('exp_month', cardData.get('exp_month'));
                cardFields.put('exp_year', cardData.get('exp_year'));
                cardFields.put('fingerprint', cardData.get('fingerprint'));
                cardFields.put('funding', cardData.get('funding'));
                cardFields.put('last4', cardData.get('last4'));
                extractedData.put('card_data', cardFields);
            }
            
            // Bank account data
            Map<String, Object> bankAccountData = (Map<String, Object>) paymentMethodData.get('us_bank_account');
            if (bankAccountData != null) {
                Map<String, Object> bankFields = new Map<String, Object>();
                bankFields.put('account_type', bankAccountData.get('account_type'));
                bankFields.put('account_holder_type', bankAccountData.get('account_holder_type'));
                bankFields.put('bank_name', bankAccountData.get('bank_name'));
                bankFields.put('last4', bankAccountData.get('last4'));
                bankFields.put('routing_number', bankAccountData.get('routing_number'));
                extractedData.put('bank_account_data', bankFields);
            }
            
            // Billing details
            Map<String, Object> billingDetails = (Map<String, Object>) paymentMethodData.get('billing_details');
            if (billingDetails != null) {
                Map<String, Object> billingFields = new Map<String, Object>();
                billingFields.put('name', billingDetails.get('name'));
                billingFields.put('email', billingDetails.get('email'));
                billingFields.put('phone', billingDetails.get('phone'));
                
                Map<String, Object> addressData = (Map<String, Object>) billingDetails.get('address');
                if (addressData != null) {
                    Map<String, Object> addressFields = new Map<String, Object>();
                    addressFields.put('line1', addressData.get('line1'));
                    addressFields.put('line2', addressData.get('line2'));
                    addressFields.put('city', addressData.get('city'));
                    addressFields.put('state', addressData.get('state'));
                    addressFields.put('postal_code', addressData.get('postal_code'));
                    addressFields.put('country', addressData.get('country'));
                    billingFields.put('address', addressFields);
                }
                
                extractedData.put('billing_details', billingFields);
            }
            
            // Show mapping to Salesforce fields
            Map<String, Object> fieldMapping = new Map<String, Object>();
            
            // Payment Method Type mapping
            String pmType = (String) paymentMethodData.get('type');
            if ('card'.equalsIgnoreCase(pmType)) {
                fieldMapping.put('Payment_Type__c', 'Credit Card');
            } else if ('us_bank_account'.equalsIgnoreCase(pmType)) {
                fieldMapping.put('Payment_Type__c', 'ACH');
            }
            
            // Card specific mappings
            if (cardData != null) {
                String brand = (String) cardData.get('brand');
                if ('visa'.equalsIgnoreCase(brand)) {
                    fieldMapping.put('Card__c', 'Visa');
                } else if ('mastercard'.equalsIgnoreCase(brand)) {
                    fieldMapping.put('Card__c', 'Master Card');
                }
                
                fieldMapping.put('Card_Last_4_Digit__c', cardData.get('last4'));
                
                Object expMonth = cardData.get('exp_month');
                if (expMonth != null) {
                    String monthStr = String.valueOf(expMonth);
                    if (monthStr.length() == 1) monthStr = '0' + monthStr;
                    fieldMapping.put('Card_Expire_Month__c', monthStr);
                }
                
                fieldMapping.put('Card_Expire_Year__c', String.valueOf(cardData.get('exp_year')));
                
                String funding = (String) cardData.get('funding');
                if ('credit'.equalsIgnoreCase(funding)) {
                    fieldMapping.put('Funding__c', 'Credit');
                } else if ('debit'.equalsIgnoreCase(funding)) {
                    fieldMapping.put('Funding__c', 'Debit');
                }
            }
            
            // Billing details mappings
            if (billingDetails != null) {
                fieldMapping.put('Email__c', billingDetails.get('email'));
                fieldMapping.put('Name_On_Card__c', billingDetails.get('name'));
                
                String billingName = (String) billingDetails.get('name');
                if (String.isNotBlank(billingName)) {
                    List<String> nameParts = billingName.trim().split(' ');
                    if (nameParts.size() >= 1) {
                        fieldMapping.put('First_Name__c', nameParts[0]);
                        if (nameParts.size() > 1) {
                            List<String> lastNameParts = new List<String>();
                            for (Integer i = 1; i < nameParts.size(); i++) {
                                lastNameParts.add(nameParts[i]);
                            }
                            fieldMapping.put('Last_Name__c', String.join(lastNameParts, ' '));
                        }
                    }
                }
            }
            
            // Other standard mappings
            fieldMapping.put('Strip_Payment_ID__c', paymentMethodData.get('id'));
            fieldMapping.put('Gateway__c', 'Stripe');
            fieldMapping.put('Currency__c', 'USD');
            fieldMapping.put('Status__c', 'Valid');
            
            Map<String, Object> result = new Map<String, Object>{
                'success' => true,
                'stripe_payment_method_id' => stripePaymentMethodId,
                'raw_stripe_data' => extractedData,
                'salesforce_field_mapping' => fieldMapping,
                'message' => 'Stripe payment method data extracted successfully'
            };
            
            return JSON.serializePretty(result);
            
        } catch (Exception e) {
            System.debug('❌ Error testing Stripe payment method data extraction:');
            System.debug('  - Type: ' + e.getTypeName());
            System.debug('  - Message: ' + e.getMessage());
            System.debug('  - Stack Trace: ' + e.getStackTraceString());
            return errorJson('Failed to test Stripe payment method data extraction: ' + e.getMessage());
        }
    }

}

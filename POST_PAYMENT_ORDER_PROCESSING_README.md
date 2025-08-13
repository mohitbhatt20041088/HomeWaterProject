# Post-Payment Order Processing Solution

## Overview

This solution automatically processes orders after successful payment based on the **Installation Type** field on the Order object. Depending on the installation type, it creates either:

- **Self Install**: Creates `Fulfillment_Order__c` and `Fulfillment_Order_Productt__c` records
- **Tech Install**: Creates `Installation_Order__c` and `Installation_Order_Product__c` records

## Components Created

### 1. PostPaymentOrderProcessingController.cls
**Main controller that handles order processing logic**

#### Key Methods:
- `processOrderAfterPayment(orderId, invoiceId, paymentIntentId)` - Main processing method
- `getOrderDetails(orderId)` - Utility method to get order details

#### Processing Logic:
1. Validates the order exists and has an installation type set
2. Updates order status to "Activated"
3. Based on installation type:
   - **Self Install**: Creates fulfillment order and line items
   - **Tech Install**: Creates installation order and products
4. Returns detailed response with created records

### 2. PostPaymentOrderProcessingHelper.cls
**Helper class with additional utility methods**

#### Key Methods:
- `processOrderByIdAfterPayment(orderId, paymentIntentId)` - Process specific order
- `processPendingOrdersForAccount(accountId, paymentIntentId)` - Process all pending orders for account
- `getOrdersWithInstallationTypes(limitCount)` - Get orders with installation types (monitoring)
- `checkOrderProcessingStatus(sourceOrderId)` - Check if order was processed

### 3. Enhanced StripeIntentController.cls
**Modified to automatically trigger order processing after payment**

#### Changes Made:
- Added logic in `updateInvoiceAfterPayment` method to automatically process pending orders
- Looks for Draft orders related to the payment account
- Calls `PostPaymentOrderProcessingController.processOrderAfterPayment` automatically
- Non-blocking - payment success is not affected by order processing errors

## Flow Diagram

```
Payment Success
      ↓
Update Invoice Status
      ↓
Look for Pending Orders (Status = 'Draft')
      ↓
Check Installation Type
      ↓
┌─────────────────┬─────────────────┐
│   Self Install  │  Tech Install   │
│        ↓        │        ↓        │
│ Create Fulfillment │ Create Installation │
│    Order        │     Order       │
│        ↓        │        ↓        │
│ Create Fulfillment │ Create Installation │
│ Order Line Items│ Order Products  │
└─────────────────┴─────────────────┘
      ↓
Update Order Status to 'Activated'
      ↓
Return Success Response
```

## Self Install Processing

When installation type is "Self Install":

### Creates Fulfillment_Order__c:
```
- Name: 'FO-' + OrderNumber
- Account__c: Order's AccountId
- Status__c: 'New'
- Total_Amount__c: Order's TotalAmount
- Source_Order_Id__c: Original Order ID
- Payment_Intent_Id__c: Stripe Payment Intent ID
- Related_Invoice__c: Invoice ID
```

### Creates Fulfillment_Order_Productt__c (Line Items):
```
- Name: FulfillmentOrder.Name + ' - ' + Product.Name
- Fulfillment_Order__c: Related Fulfillment Order
- Product__c: Product from OrderItem
- Quantity__c: OrderItem Quantity
- Unit_Price__c: OrderItem UnitPrice
- Total_Price__c: OrderItem TotalPrice
- Status__c: 'New'
- Order_Product_Id__c: Original OrderItem ID
```

## Tech Install Processing

When installation type is "Tech Install":

### Creates Installation_Order__c:
```
- Name: 'IO-' + OrderNumber
- Account__c: Order's AccountId
- Status__c: 'Scheduled'
- Total_Amount__c: Order's TotalAmount
- Installation_Order_Number__c: Auto-generated number
- Type__c: 'Tech Installation'
- Source_Order_Id__c: Original Order ID
- Payment_Intent_Id__c: Stripe Payment Intent ID
- Related_Invoice__c: Invoice ID
```

### Creates Installation_Order_Product__c:
```
- Name: InstallationOrder.Name + ' - ' + Product.Name
- Installation_Order__c: Related Installation Order
- Product__c: Product from OrderItem
- Order_Product__c: Original OrderItem ID
- Quantity__c: OrderItem Quantity
- Unit_Price__c: OrderItem UnitPrice
- Gross_Unit_Price__c: OrderItem UnitPrice
- Line_Subtotal__c: OrderItem TotalPrice
- ServiceDate__c: 3 days from today (default)
```

## Required Custom Fields

The solution assumes these fields exist (you mentioned not to create object-related files):

### On Fulfillment_Order__c:
- `Source_Order_Id__c` (Lookup to Order)
- `Payment_Intent_Id__c` (Text)
- `Related_Invoice__c` (Lookup to Invoice__c)

### On Installation_Order__c:
- `Source_Order_Id__c` (Lookup to Order)
- `Payment_Intent_Id__c` (Text)
- `Related_Invoice__c` (Lookup to Invoice__c)

### On Order (already exists):
- `Installation_Type__c` (Picklist with "Self Install" and "Tech Install")

## Usage Examples

### Automatic Processing (Integrated with Payment Flow)
```apex
// This happens automatically when payment is processed
String result = StripeIntentController.updateInvoiceAfterPayment(
    invoiceId, 
    stripePaymentIntentId, 
    amountCents, 
    cardholderName
);
```

### Manual Processing
```apex
// Process specific order manually
String result = PostPaymentOrderProcessingController.processOrderAfterPayment(
    orderId, 
    invoiceId, 
    paymentIntentId
);

// Process all pending orders for an account
String result = PostPaymentOrderProcessingHelper.processPendingOrdersForAccount(
    accountId, 
    paymentIntentId
);
```

### Monitoring and Debugging
```apex
// Check if an order was processed
String status = PostPaymentOrderProcessingHelper.checkOrderProcessingStatus(orderId);

// Get orders with installation types
String orders = PostPaymentOrderProcessingHelper.getOrdersWithInstallationTypes(10);

// Get order details
String details = PostPaymentOrderProcessingController.getOrderDetails(orderId);
```

## Error Handling

- **Non-blocking**: Payment success is not affected by order processing errors
- **Detailed logging**: All operations are logged with System.debug statements
- **Graceful degradation**: If order processing fails, payment still completes successfully
- **Standardized error responses**: All methods return consistent JSON error responses

## Integration Points

### 1. Payment Flow Integration
- Automatically triggered after successful payment in `StripeIntentController.updateInvoiceAfterPayment`
- Looks for pending orders (Status = 'Draft') related to the payment account

### 2. Order Creation Integration
- Works with existing order creation flow in `CreateSalesRecordsController`
- Requires Installation_Type__c to be set during order creation

### 3. Custom Object Integration
- Leverages existing custom objects you've already created
- Creates relationships between source orders and fulfillment/installation orders

## Testing Scenarios

### Test Case 1: Self Install Order
1. Create an Order with Installation_Type__c = 'Self Install'
2. Process payment successfully
3. Verify Fulfillment_Order__c and Fulfillment_Order_Productt__c records are created

### Test Case 2: Tech Install Order
1. Create an Order with Installation_Type__c = 'Tech Install'
2. Process payment successfully
3. Verify Installation_Order__c and Installation_Order_Product__c records are created

### Test Case 3: Manual Processing
1. Use `PostPaymentOrderProcessingHelper.processOrderByIdAfterPayment()` to process specific order
2. Use `PostPaymentOrderProcessingHelper.processPendingOrdersForAccount()` to process all orders for account

### Test Case 4: Status Checking
1. Use `PostPaymentOrderProcessingHelper.checkOrderProcessingStatus()` to verify processing results
2. Confirm correct fulfillment or installation orders were created

## Benefits

1. **Automated Processing**: Orders are automatically processed after payment without manual intervention
2. **Type-based Logic**: Different processing paths based on installation type
3. **Comprehensive Tracking**: Full traceability from original order to fulfillment/installation orders
4. **Error Resilience**: Payment flow continues even if order processing encounters issues
5. **Flexible Usage**: Can be used automatically or manually triggered
6. **Monitoring Capabilities**: Built-in methods to check processing status and monitor orders

## Next Steps

1. Deploy the Apex classes to your org
2. Ensure the required custom fields exist on your custom objects
3. Test the payment flow with both installation types
4. Monitor the debug logs to verify proper processing
5. Use the helper methods to check processing status and troubleshoot any issues

This solution provides a robust, scalable approach to handling post-payment order processing based on installation types while maintaining the integrity of your payment flow.

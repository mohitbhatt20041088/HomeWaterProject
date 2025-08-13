System.debug('Testing createPaymentIntent method...');
String result = StripeIntentController.createPaymentIntent(100, 'usd', 'test payment', 'test@example.com');
System.debug('Result: ' + result);

@isTest
private class OrderConfirmationEmailServiceTest {

    @testSetup
    static void setupTestData() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'INV-123456',
            StageName = 'Negotiation/Review',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;
    }

    private static Messaging.InboundEmailResult runEmailHandler(String subject, String body) {
        OrderConfirmationEmailService svc = new OrderConfirmationEmailService();

        Messaging.InboundEmail email = new Messaging.InboundEmail();
        email.subject = subject;
        email.plainTextBody = body;

        Messaging.InboundEnvelope env = new Messaging.InboundEnvelope();

        return svc.handleInboundEmail(email, env);
    }

    @isTest
    static void testApprovedMovesToNextStage() {
        Messaging.InboundEmailResult result = runEmailHandler(
            'Заказ INV-123456',
            'Подтверждаю заказ, Approved'
        );

        System.assert(result.success);
        System.assert(result.message.contains('статус изменен'));

        Opportunity updatedOpp = [SELECT StageName FROM Opportunity WHERE Name = 'INV-123456'];
        System.assertEquals('Pending Confirmation', updatedOpp.StageName);
    }

    @isTest
    static void testRejectedMovesToClosedLost() {
        Messaging.InboundEmailResult result = runEmailHandler(
            'Order INV-123456',
            'Отклоняю заказ, Rejected'
        );

        System.assert(result.success);
        System.assert(result.message.contains('Closed Lost'));

        Opportunity updatedOpp = [SELECT StageName FROM Opportunity WHERE Name = 'INV-123456'];
        System.assertEquals('Closed Lost', updatedOpp.StageName);
    }

    @isTest
    static void testUnknownResponseFails() {
        Messaging.InboundEmailResult result = runEmailHandler(
            'Order INV-123456',
            'Какой-то непонятный текст'
        );

        System.assert(!result.success);
        System.assert(result.message.contains('Неизвестный ответ'));
    }

    @isTest
    static void testOrderNumberNotFoundFails() {
        Messaging.InboundEmailResult result = runEmailHandler(
            'Нет номера заказа',
            'Approved'
        );

        System.assert(!result.success);
        System.assert(result.message.contains('Номер заказа не найден')); // заглавная Н
    }

    @isTest
    static void testOpportunityNotFoundFails() {
        Messaging.InboundEmailResult result = runEmailHandler(
            'Order INV-999999',
            'Approved'
        );

        System.assert(!result.success);
        System.assert(result.message.contains('не найдена'));
    }
}
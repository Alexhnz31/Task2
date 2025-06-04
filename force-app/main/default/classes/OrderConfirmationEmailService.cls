global class OrderConfirmationEmailService implements Messaging.InboundEmailHandler {
    
    global Messaging.InboundEmailResult handleInboundEmail(
        Messaging.InboundEmail email,
        Messaging.InboundEnvelope envelope
    ) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailResult();
        
        try {
            String orderNumber = extractOrderNumber(email.subject, email.plainTextBody);
            
            if (String.isBlank(orderNumber)) {
                result.success = false;
                result.message = '❌ Номер заказа не найден в письме';
                return result;
            }
            
            Opportunity opp = findOpportunityByOrderNumber(orderNumber);
            
            if (opp == null) {
                result.success = false;
                result.message = '❌ Сделка с номером ' + orderNumber + ' не найдена';
                return result;
            }
            
          List<String> allowedStages = new List<String>{'Pending Confirmation', 'Prospecting', 'Negotiation'};
if (!allowedStages.contains(opp.StageName)) {
    result.success = false;
    result.message = '❌ Сделка не в подходящем статусе для подтверждения';
    return result;
}
            
            String response = parseResponse(email.plainTextBody);
            
            if ('APPROVED'.equalsIgnoreCase(response)) {
                opp.StageName = 'Closed Won'; 
                result.message = '✅ Сделка подтверждена, статус изменен на "Closed Won"';
            } 
            else if ('REJECTED'.equalsIgnoreCase(response)) {
                opp.StageName = 'Closed Lost'; 
                result.message = '❌ Сделка отклонена, статус изменен на "Closed Lost"';
            } 
            else {
                result.success = false;
                result.message = '❌ Неизвестный ответ в письме (должно быть Approved/Rejected)';
                return result;
            }
            
            update opp;
            result.success = true;
            
        } catch (Exception e) {
            result.success = false;
            result.message = '⛔ Ошибка обработки письма: ' + e.getMessage();
        }
        
        return result;
    }
    
    private String extractOrderNumber(String subject, String body) {
        Pattern pattern = Pattern.compile('INV-\\d{6}'); 
        Matcher matcher = pattern.matcher(subject + ' ' + body);
        
        return matcher.find() ? matcher.group() : null;
    }
    
    private Opportunity findOpportunityByOrderNumber(String orderNumber) {
        List<Opportunity> opps = [
            SELECT Id, StageName 
            FROM Opportunity 
            WHERE Invoice_Number__c = :orderNumber 
            LIMIT 1
        ];
        return opps.isEmpty() ? null : opps[0];
    }
    
    private String parseResponse(String emailBody) {
        
        if (emailBody.contains('Approved') || emailBody.contains('approve') || 
            emailBody.contains('Подтверждаю') || emailBody.contains('Согласен')) {
            return 'APPROVED';
        } 
        else if (emailBody.contains('Rejected') || emailBody.contains('reject') || 
                 emailBody.contains('Отклоняю') || emailBody.contains('Отказ')) {
            return 'REJECTED';
        }
        return null;
    }
}
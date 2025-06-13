global class OrderConfirmationEmailService implements Messaging.InboundEmailHandler {
    
    // Define the stage progression order
    private static final List<String> STAGE_PROGRESSION = new List<String>{
        'Prospecting',
        'Qualification',
        'Needs Analysis',
        'Value Proposition',
        'Id. Decision Makers',
        'Perception Analysis',
        'Proposal/Price Quote',
        'Negotiation/Review',
        'Pending Confirmation',
        'Closed Won',
        'Closed Lost'
    };
    
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
            
            String response = parseResponse(email.plainTextBody);
            
            if ('APPROVED'.equalsIgnoreCase(response)) {
                // Move to next stage for approval
                String nextStage = getNextStage(opp.StageName);
                if (nextStage != null) {
                    opp.StageName = nextStage;
                    result.message = '✅ Сделка подтверждена, статус изменен на "' + nextStage + '"';
                } else {
                    result.success = false;
                    result.message = '❌ Сделка уже находится на финальном этапе';
                    return result;
                }
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
    
    private String getNextStage(String currentStage) {
        Integer currentIndex = STAGE_PROGRESSION.indexOf(currentStage);
        if (currentIndex == -1 || currentIndex == STAGE_PROGRESSION.size() - 1) {
            return null; // Current stage not found or already at last stage
        }
        return STAGE_PROGRESSION[currentIndex + 1];
    }
}
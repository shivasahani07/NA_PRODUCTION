public class SendPayableDetailsToCustomer {
    
    Public static AuditResponseWrapperClass sendPayableDetails(Id taskRecordId){
        String auditResult = Label.AuditAPIFailedStatus;
        system.debug('taskRecordId::'+taskRecordId);
        List<Document_Handler__c> docHandlerList 	= new List<Document_Handler__c>();
        List<Paybale__c> payableList 				= new List<Paybale__c>();
        List<Document_Handler__c> docHanlderTobeUpdate = new List<Document_Handler__c>();
        List<IDFC_Payout_Metadata__mdt> payoutMetaDataList = new List<IDFC_Payout_Metadata__mdt>();
        Map<String,IDFC_Payout_Metadata__mdt> mapOfCompareValueByResultValue = new Map<String,IDFC_Payout_Metadata__mdt>();
        AuditResponseWrapperClass auditResponse = new AuditResponseWrapperClass();
        auditResponse.auditRec = new API_Callout_Audit__c();
        try{
            Id dependantTaskRecordId = [select Id,Execution_Depended_Closed_Task_Ids__c,Parent_Task_Id__c from Task where Id =: taskRecordId].Parent_Task_Id__c;
            payoutMetaDataList = [SELECT Id,Compare_Value__c,Matching_Type__c,Purpose_Code__c from IDFC_Payout_Metadata__mdt];
            
            if(!payoutMetaDataList.isEMpty()){
                for(IDFC_Payout_Metadata__mdt idfcPayout : payoutMetaDataList){
                    mapOfCompareValueByResultValue.put(idfcPayout.Compare_Value__c,idfcPayout);
                }
            }
            //ID nextDependantTaskId = [select Id,Execution_Depended_on_Task_Ids__c from task where Parent_Task_Id__c =: taskRecordId].Id;
            system.debug('dependantTaskRecordId::'+dependantTaskRecordId);
            Set<Id> payableIdSet = new Set<Id>();
            Map<ID,Paybale__c> mapofPayableIdByDet = new Map<ID,Paybale__c>();
            system.debug('docHandlerList::'+taskRecordId);
            
            payableList		= [SELECT Id,Value_Date__c,Amount__C,Financial_Entity_A_C_Details__c,Financial_Entity_A_C_Details__r.Bank_Account_Number__c,
                               Financial_Account__r.Name,Payable_File_Name__c,Financial_Entity_A_C_Details__r.Banking_Account_Name__c,
                               Financial_Entity_A_C_Details__r.IFSC_Code__c,Mode__c,Task_Id__c,Financial_Entity_A_C_Details__r.Bank_Account_Type__c,
                               Financial_Account__r.Originating_Branch__r.Name	  
                               FROM Paybale__c 
                               Where Task_Id__c =: dependantTaskRecordId and Status__c =: Constants.PAYABLE_STATUS_MEMO_CREATED and Execution_Request_Processed__c = false];
            
            system.debug('payableList::'+payableList);
            if(!payableList.isEmpty()){
                for(Paybale__c payRec : payableList){
                    payRec.Status__c = Constants.DOC_HANDLER_SUBMITTED_FOR_EXECUTION;
                    payRec.Execution_Request_Processed__c = true;
                    mapofPayableIdByDet.put(payRec.Id,payRec);
                    
                }
                
                
                docHanlderTobeUpdate = [SELECT Id,Extended_SObject_RecordId__c
                                        from Document_Handler__c 
                                        where Extended_SObject_RecordId__c in: mapofPayableIdByDet.keySet()];
                
                String csvContent = 'Client Code,Debit Account No,Transaction Type Code,Value Date,Amount,Beneficary Name,Beneficary Accunt no.,IFSC code,Customer Ref no.,Beneficary email id,Beneficary mobile no.,Remarks,Payment Type,Purpose code,Bene a/c type,Payable Location,Print Branch Name,Mode of delivery,Transaction currency,BENE_ADD1,BENE_ADD2,BENE_ADD3,BENE_ADD4\n'; // Replace with actual field names
                
                // Add data rows
                for (Paybale__c payRec : payableList) {
                    system.debug('payRec::'+payRec);
                    if(payRec.Value_Date__c == null){
                        payRec.Value_Date__c = system.today();
                    }
                    if(payRec.Financial_Entity_A_C_Details__r.IFSC_Code__c == null){
                        payRec.Financial_Entity_A_C_Details__r.IFSC_Code__c = '';
                    }
                    if(payRec.Financial_Entity_A_C_Details__r.Banking_Account_Name__c == null){
                        payRec.Financial_Entity_A_C_Details__r.Banking_Account_Name__c = '';
                    }
                    String clientCode = 'NACLCH';
                    String transactionTypeCode = 'CC';
                    String paymentType = '';
                    String purposeCode = '';
                    String accountType = '';
                    String deliveryMode = 'BP'; 
                    String transactionType = 'INR';
                    if(!mapOfCompareValueByResultValue.isEMpty()){
                        if(mapOfCompareValueByResultValue.containsKey('NACL') && payRec.Mode__c != 'Cheque'){
                            clientCode = mapOfCompareValueByResultValue.get('NACL').Matching_Type__c;
                        }
                        if(mapOfCompareValueByResultValue.containsKey(payRec.Mode__c)){
                            transactionTypeCode = mapOfCompareValueByResultValue.get(payRec.Mode__c).Matching_Type__c;
                        }
                        system.debug('payRec.Mode__c::'+payRec.Mode__c);
                        if(payRec.Mode__c != 'Cheque' && (payRec.Mode__c == 'RTGS' || payRec.Mode__c == 'NEFT')){
                            
                            
                            if(mapOfCompareValueByResultValue.containsKey(payRec.Mode__c)){
                                paymentType = mapOfCompareValueByResultValue.get(payRec.Mode__c).Compare_Value__c;//Validate
                            }
                            
                            if(mapOfCompareValueByResultValue.containsKey(payRec.Mode__c)){
                                purposeCode = mapOfCompareValueByResultValue.get(payRec.Mode__c).Purpose_Code__c;//Validate
                            }
                        }
                        if(mapOfCompareValueByResultValue.containsKey(payRec.Financial_Entity_A_C_Details__r.Bank_Account_Type__c)){
                            accountType = mapOfCompareValueByResultValue.get(payRec.Financial_Entity_A_C_Details__r.Bank_Account_Type__c).Matching_Type__c;
                        }
                        
                        
                        
                    }
                    
                    
                    csvContent += '"' + String.valueOf(clientCode).escapeCsv() + '","' +//Client Code
                        String.valueOf(payRec.Financial_Entity_A_C_Details__r.Bank_Account_Number__c).escapeCsv() + '","' +//Debit Account No
                        String.valueOf(transactionTypeCode).escapeCsv() + '","' +//Transaction Type Code
                        String.valueOf(payRec.Value_Date__c).escapeCsv() + '","' +//Value Date
                        String.ValueOf(payRec.Amount__c).escapeCsv() + '","' +//Amount
                        payRec.Financial_Entity_A_C_Details__r.Banking_Account_Name__c.escapeCsv() + '","';//Ben Name
                    system.debug('CSV1111:::'+csvContent);
                    if((payRec.Mode__c == 'RTGS' || payRec.Mode__c == 'NEFT')){
                        csvContent += String.valueOf(payRec.Financial_Entity_A_C_Details__r.Bank_Account_Number__c).escapeCsv() + '","' +//Ben Account No
                            payRec.Financial_Entity_A_C_Details__r.IFSC_Code__c.escapeCsv() + '","';//IFSC Code
                    }else{
                        csvContent += + '","'+
                            + '","' ;
                    }
                    system.debug('CSV2222:::'+csvContent);
                    csvContent += String.valueOf(payRec.Payable_File_Name__c).escapeCsv() + '","' +//Customer ref No
                        + '","' +  // Beneficary Email Id
                        + '","' + // beneficary Mobile No.
                        + '","' ; // Remarks
                    if(payRec.Mode__c == 'RTGS' || payRec.Mode__c == 'NEFT'){
                        csvContent += String.valueOf(payRec.Mode__C.escapeCsv())  + '","' +//payment type
                            String.valueOf(purposeCode).escapeCsv()  + '","' ;//Purpose Code
                    }else{
                        csvContent += + '","' +
                            + '","' ;  
                    }
                    system.debug('CSV333:::'+csvContent);
                    csvContent += '","' + // Beneficary Account Type
                        + '","' + // Payable Location
                        + '","' + // Print Branch Name
                        String.valueOf(deliveryMode).escapeCsv()  + '","' +//Mode of delivery
                        String.valueOf(transactionType).escapeCsv()  + '","' ;//Transaction Currency
                    if(payRec.Mode__c == 'Cheque'){
                        csvContent +=  'Northern Arc Capital'.escapeCsv()  + '","' +//,
                            String.valueOf(payRec.Financial_Account__r.Originating_Branch__r.Name).escapeCsv()  + '","' + 
                            + '","' +
                            String.valueOf(payRec.Financial_Account__r.Name).escapeCsv()  + '","' +
                            + '","' +  '"\n';
                        
                    }else{
                        csvContent +=  + '","' + // BENE_ADD1
                            + '","' + //BENE_ADD2
                            + '","' + //BENE_ADD3
                            + '","' + //BENE_ADD4
                            + '","' +  '"\n';
                    }
                    
                    system.debug('CSV444:::'+csvContent);
                }
                
                // Convert CSV string to Blob
                Document_Handler__c docHandler = new Document_Handler__c();
                Document_Metadata__c docMetaRec = [select id,Document_Name__c from Document_Metadata__c where Document_Name__c='MEMO Submitted For Request' limit 1];
                system.debug('docMetaRec::'+docMetaRec);
                docHandler.Task_Id__c = taskRecordId;
                docHandler.Status__c = 'Completed';
                docHandler.Document_Metadata__c = docMetaRec.Id;
                insert docHandler;
                system.debug('docHandler::'+docHandler);
                ContentVersion file = new ContentVersion(
                    title = 'PayableAccount.csv'+taskRecordId,
                    versionData = Blob.valueOf( csvContent ),
                    pathOnClient = '/PayableAccounts.csv',
                    FirstPublishLocationId = docHandler.Id
                );
                insert file;
                for(Paybale__c payRec : payableList){
                    payRec.Execution_Request_Document_Handler__c = docHandler.Id;
                }
                update payableList;
                system.debug('file::'+file);
                auditResponse = EmailService.ExecuteEmailServices(taskRecordId,docHandler.Id);
                if(!docHanlderTobeUpdate.isEmpty()){
                    for(Document_Handler__c docHandlerRec : docHanlderTobeUpdate){
                        docHandlerRec.Status__c = Constants.DOC_HANDLER_SUBMITTED_FOR_EXECUTION;
                    }
                    
                    update docHanlderTobeUpdate;
                }
                //update payableList;
            }
            auditResponse.auditRec.API_Status__c = Label.AuditAPIStatus;
            auditResult = Label.AuditAPIStatus;
        }catch(Exception e){
            system.debug('exception::'+e);
            system.debug('exception line::'+e.getStackTraceString());
            auditResponse.auditRec.Response__c = e.getStackTraceString();
            auditResponse.auditRec.API_Status__c = Label.AuditAPIFailedStatus;
        }
        
        return auditResponse;
        
    }
}
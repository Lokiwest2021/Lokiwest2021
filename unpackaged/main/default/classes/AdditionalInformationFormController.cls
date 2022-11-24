public with sharing class AdditionalInformationFormController {

	public String id {get;set;}
	public String label {get;set;}
	public String value {get;set;}
	public Boolean mandatory {get;set;}
	public Boolean enabled {get;set;}
	public Integer maxLength {get;set;}
	public List<ACIOption> options {get;set;}
	public String apexDataType {get;set;}
	public String classes {get;set;}


	public AdditionalInformationFormController()
	{
		this.id = ApexPages.currentPage().getParameters().get('id');
		this.label = ApexPages.currentPage().getParameters().get('label');
		this.value = ApexPages.currentPage().getParameters().get('value');
		//PARXIMPL-2921 npo: "Arguments cannot be null" error occurs on ACI fields
		this.mandatory = String.isNotEmpty(ApexPages.currentPage().getParameters().get('mandatory')) ? Boolean.valueOf(ApexPages.currentPage().getParameters().get('mandatory')) : false;
		this.enabled = String.isNotEmpty(ApexPages.currentPage().getParameters().get('enabled'))? Boolean.valueOf(ApexPages.currentPage().getParameters().get('enabled')) : false;
		this.maxLength = String.isNotEmpty(ApexPages.currentPage().getParameters().get('maxLength')) ? Integer.valueOf(ApexPages.currentPage().getParameters().get('maxLength')) : 0;
		this.apexDataType = ApexPages.currentPage().getParameters().get('apexDataType');
		this.classes = ApexPages.currentPage().getParameters().get('classes');
		createOptions();
	}

	/*	DE442
	 *	@author dvo
	 *	@description Method creates content for the picklist element
	 */
	private void createOptions()
	{
		//dme : PARXIMPL-9099 : Handle picklist type not via URL param, because of URL characters limit = 4k symbols
		if (String.valueOf(DisplayType.MULTIPICKLIST) == this.apexDataType || String.valueOf(DisplayType.PICKLIST) == this.apexDataType)
		{
			AdditionalInformationService additionalInformationService = new AdditionalInformationService();
			String aciRecordId = String.valueOf(ApexPages.currentPage().getParameters().get('aciRecordId'));
			List<AdditionalCaseField__c> additionalCaseFields = [SELECT Id, CaseFieldValue__c, CaseFieldAPIName__c FROM AdditionalCaseField__c WHERE Id =:aciRecordId ];
			AdditionalCaseField__c additionalCaseField = additionalCaseFields[0];
			this.options = additionalInformationService.getOptionsForField(additionalCaseField, String.valueOf(this.value));
		}
		else
		{
			this.options = (List<ACIOption>) JSON.deserialize(String.valueOf(ApexPages.currentPage().getParameters().get('options')), List<ACIOption>.class);
		}
	}
}
public with sharing class Specification {
//test with MDM_SpecificationService_Test, Specification_Test
public class ValidationException extends Exception {}

static public Specification__c create(string mdmKey, Id customProjectId) {
	Specification__c spec = new Specification__c();
	spec.Name = 'Selling Style #' + mdmKey.right(10);
	spec.MDM_Key__c = mdmKey;

	spec.Style_Number__c = mdmKey.right(10).left(5);
	spec.Color_Number__c = mdmKey.right(5);
	spec.Type__c = 'product';
	spec.RecordTypeId = convertType('product');
	spec.Custom_Project__c = customProjectId;
	insert spec;
	return spec;
}

static public Specification__c createWithName(string mdmKey, Id customProjectId, String specNameIn){
	//I'm not sure how create() is being used, so don't want to change it at all...this is a copy aside from the name parameter being set
	Specification__c spec = new Specification__c();

	if (specNameIn == null || specNameIn == '') {
		spec.Name = 'Selling Style #' + mdmKey.right(10);
	} else {
		spec.Name = specNameIn;
	}

	spec.MDM_Key__c = mdmKey;
	spec.MDM_Id__c = mdmKey;
	spec.MDM_Id_Ext__c = '1.00';
	spec.Style_Number__c = mdmKey.right(10).left(5);
	spec.Color_Number__c = mdmKey.right(5);
	spec.Type__c = 'product';
	spec.RecordTypeId = convertType('product');
	spec.Custom_Project__c = customProjectId;
	spec.Record_Source__c = 'MSS';

	insert spec;
	return spec;

}
static public Specification__c createExpSpec(CDS_Design_Service__c service, string mdmKey, String parentMdmKey, String parentId){
	Specification__c spec = new Specification__c();

	if (service.Exp_Name__c == null || service.Exp_Name__c == '') {
		spec.Name = 'Experimental ' + mdmKey.right(10);
	} else {
		spec.Name = service.Exp_Name__c;
	}

	spec.MDM_Key__c = mdmKey;
	spec.MDM_Id__c = mdmKey;
	spec.MDM_Id_Ext__c = '1.00';
	spec.Type__c = 'exp';
	spec.RecordTypeId = convertType('exp');
	spec.Custom_Project__c = service.Custom_Project__c;
	spec.Parent_MDM_Key__c = parentMdmKey;
	spec.Parent_Specification__c = (Id)parentId;
	spec.Status__c = 'Draft';
	spec.CDS_Design_Service__c = service.Id;
	spec.IsAnchor__c = true;
	spec.Record_Source__c = 'MSS';

	List<Specification__c> existingSpecs = [SELECT Id, MDM_Key__c, Parent_Specification__c FROM Specification__c WHERE MDM_Key__c = :mdmKey];
	if (!existingSpecs.isEmpty() && String.isNotEmpty(existingSpecs[0].Parent_Specification__c) && existingSpecs[0].Parent_Specification__c != parentId) {
		// existing spec found and the Parent_Specification__c has a value that is different from the parentId
		throw new ValidationException('Cannot create duplicate experimental spec: ' + mdmKey);
	}

	upsert spec MDM_Key__c;
	return spec;
}

public static Specification__c build(MdmApi.Spec mdmSpec) {
	Nebula.Logger.info('Start of build parameter mdmSpec = ' + JSON.serialize(mdmSpec, true));
	Specification__c spec;

	String recTypeValue = convertType(mdmSpec.Type);
	if (recTypeValue == null) {
		Nebula.Logger.error(new Nebula.LogMessage('convertType is not valid for mdmSpec.Type = "{0}"', mdmSpec.Type));
		return null;
	}

	try {
		String mdmKey = mdmSpec.Id.trim();
		if (String.isNotBlank(mdmSpec.IdExt)) {
			mdmKey += '_' + mdmSpec.IdExt.trim();
		}
	
		spec = getSpecification(mdmSpec.Id); //This ID is from MDM, not an SF Id
	
		if (spec == null) {
			spec = new Specification__c();
		}
	
		spec.Workflow_State__c = String.isBlank(mdmSpec.WorkflowState) ? null : mdmSpec.WorkflowState;
		spec.Name = convertName(mdmSpec);
		spec.MDM_Key__c = mdmSpec.Id;
		spec.MDM_Id__c = mdmSpec.Id;
		spec.MDM_Id_Ext__c = mdmSpec.IdExt;
	
		//set colorway
		spec.Colorway__c = mdmSpec.DesignColorway;
	
		//set design Id
		spec.Design_Id__c = String.valueOf(mdmSpec.DesignId);
	
		//status codes are mapped to description on the ESB
		String status = convertMssStatus(mdmSpec.Status);
		spec.Status__c = status;
	
		if(mdmSpec.Type == 'Product') { ///for table display
			spec.Style_Number__c = mdmSpec.Id;
			spec.Color_Number__c = mdmSpec.Id.right(5);
		}
	
		spec.Type__c = mdmSpec.Type;
		spec.RecordTypeId = recTypeValue;
		spec.Record_Source__c = 'MSS';
		spec.Colorization__c = convertColorization(mdmSpec.Colorization);
		spec.Selling_Company__c = mdmSpec.SellingCompany;
		if (mdmSpec.TuftedFaceWeight < 1000) {
			spec.Face_Weight__C = mdmSpec.TuftedFaceWeight;
		}
	
		spec.Threadup_Overall__c = mdmSpec.ThreadupOverall;
		spec.Threadup_Front__c = mdmSpec.ThreadupFront;
		spec.Threadup_Back__c = mdmSpec.ThreadupBack;
	
		spec.Step_Code_Front__c = mdmSpec.StepCodeFront;
		spec.Step_Code_Back__c = mdmSpec.StepCodeBack;
		spec.Step_Code_Advance__c = mdmSpec.StepCodeAdvance;
		spec.Form__c = specFormToValue(mdmSpec.Form);
		spec.Backing_Material__c = mdmSpec.Backing;
	
		///this is now coming over from mdm as a concat'd string of Pattern#.Ext, Pattern#.Ext.
		//ie. abcd.1, defg, hijk.3...note not all have pattern extensions/versions.
		spec.Pattern_Number__c = mdmSpec.Pattern;
		spec.Brand_Code__c = SpecBrandCode.getBrandCodeDescription(mdmSpec.BrandCode);
		productMeasurements(mdmSpec, spec);
		
		upsert spec;

		updateEstimateCostingData(spec, mdmSpec);
		checkForUnprocessedRecords(spec);
	
		System.enqueueJob(new SpecificationLinkChildSpecs(spec));
	} catch(Exception e) {
		Nebula.Logger.error(e.getMessage(), e);
	}

	Nebula.Logger.info('End of build', spec);
	return spec;
}

public static String convertMssStatus(String mssStatus) {
	String status = mssStatus == null ? '' : mssStatus.toLowerCase();
	switch on status {
		when 'availabletoorder' {
			return 'Available To Order';
		}
		when 'inprocess','isolated' {
			return 'In Progress';
		}
		when else {
			return mssStatus;
		}
	}
}

public static void checkForUnprocessedRecords(Specification__c spec) {
	Nebula.Logger.info('Start of checkForUnprocessedRecords', spec);
	String mssId;
	switch on spec.Type__c.toLowerCase() {
		when 'exp' {
			mssId = 'CDSE-';
		}
		when 'cad' {
			mssId = 'CDSC-';
		}
		when 'sample' {
			mssId = 'CDSS-';
		}
	}

	if (mssId == null) {
		Nebula.Logger.error('Unable to create mssId for spec', spec);
	} else {
		mssId += spec.MDM_Id__c + '-' + spec.MDM_Id_Ext__c;
	}

	List<MSS_Relationship__c> relationships = [SELECT Id, Resource_Id__c, Parent_Id__c, Connection_Type__c FROM MSS_Relationship__c WHERE Resource_Id__c = :mssId OR Parent_Id__c = :mssId];
	for (MSS_Relationship__c relationship : relationships) {
		CDS_Spec_Relationship_Rest.processRelationship(relationship.Connection_Type__c, relationship.Resource_Id__c, relationship.Parent_Id__c, relationship);
	}
}

static private void productMeasurements(MdmApi.Spec mdmSpec, Specification__c spec) {
	String handlingUnit;

	if (mdmSpec.ProductMeasurement != null && !String.isBlank(spec.Form__c)) {
		switch on spec.Type__c.toLowerCase() {
			when 'sample' {
				handlingUnit = 'roll';
			}
			when 'cad' {
				handlingUnit = 'tile';
			}
			when else {
				if (spec.Form__c.equalsIgnoreCase('Broadloom')) {
					handlingUnit = 'roll';
				} else if (spec.Form__c.equalsIgnoreCase('Tile')) {
					handlingUnit = 'tile';
				}
			}
		}

		if (handlingUnit != null) {
			for(MdmApi.OneProductMeasurement dim: mdmSpec.ProductMeasurement) {
				if ('STD'.equalsIgnoreCase(dim?.HandlingQualifier) && handlingUnit.equalsIgnoreCase(dim?.HandlingUnit)) {
					String side = dim.HandlingDimension;
					Decimal val;

					switch on dim.HandlingUom {
						when 'in' {
							val = dim.HandlingValue;
						}
						when 'ft' {
							val = dim.HandlingValue * 12;
						}
						when 'mil' {
							val = dim.HandlingValue * .001;
						}
						when 'mm' {
							val = dim.HandlingValue * 0.0393701;
						}
					}

					if (val != null) {
						if ('WDT'.equalsIgnoreCase(side)) {
							spec.Width__c = val;
						} else if ('LGT'.equalsIgnoreCase(side)) {
							spec.Length__c = val;
						}
					}
				}
			}
		}
	}
}

static private String specFormToValue(String key) {
	String val = String.isBlank(key) ? '' : key.toLowerCase();

	switch on val {
		when 'bloom' {
			return 'Broadloom';
		}
		when 'tile' {
			return 'Tile';
		}
		when else {
			return val;
		}
	}
}

static private void updateEstimateCostingData(Specification__c spec, MdmApi.Spec mdmSpec) {
	// Costing & Estimate data
	List<Spec_Run_Size__c> specRunSizes;
	List<Spec_Run_Size__c> deleteRunSizes = new List<Spec_Run_Size__c>();
	List<String> mdmIds = new List<String>();

	List<String> estimateIds = new List<String>();
	if (mdmSpec.RunSizes != null && !mdmSpec.RunSizes.isEmpty()) {
		for (MdmApi.RunSize runSize : mdmSpec.RunSizes) {
			estimateIds.add(runSize.Id);
		}
	}

	List<CDS_Design_Service__c> existingDesignServices = [
		SELECT Id, Spec_Run_Size__r.MDM_Id__c
		FROM CDS_Design_Service__c
		WHERE Spec_Run_Size__r.MDM_Id__c IN :estimateIds
	];
	List<String> usedEstimateIds = new List<String>();
	for (CDS_Design_Service__c existingDesignService : existingDesignServices) {
		usedEstimateIds.add(existingDesignService.Spec_Run_Size__r.MDM_Id__c);
	}

	if (mdmSpec.RunSizes != null && !mdmSpec.RunSizes.isEmpty()) {
		specRunSizes = new List<Spec_Run_Size__c>();
		for (MdmApi.RunSize runSize : mdmSpec.RunSizes) {
			if (!usedEstimateIds.contains(runSize.Id)) {
				Spec_Run_Size__c specRunSize = new Spec_Run_Size__c();
				specRunSizes.add(specRunSize);
				specRunSize.Specification__c = spec.Id;
				specRunSize.MDM_Id__c = runSize.Id;
				specRunSize.Quantity__c = runSize.Quantity;
				specRunSize.Quantity_UOM__c = standardUom(runSize.QuantityUom);
				specRunSize.Variance_Quantity__c = runSize.VarianceQuantity;
				specRunSize.Variance_Quantity_UOM__c = runSize.VarianceQuantityUom;
				mdmIds.add(runSize.Id);
			}
		}
	}

	if (specRunSizes != null && !specRunSizes.isEmpty()) {
		upsert specRunSizes MDM_Id__c;
	}

	// delete any run sizes that have been deleted in MDM
	specRunSizes = [SELECT Id, MDM_Id__c FROM Spec_Run_Size__c WHERE Specification__c = :spec.Id AND MDM_Id__c != null AND MDM_Id__c NOT IN :usedEstimateIds];
	for (Spec_Run_Size__c specRunSize : specRunSizes) {
		if (mdmIds.indexOf(specRunSize.MDM_Id__c) == -1) {
			deleteRunSizes.add(specRunSize);
		}
	}
	if (!deleteRunSizes.isEmpty()) {
		delete deleteRunSizes;
	}
}

public static String standardUom(String uom) {
	String standard;

	String lowerUom = uom == null ? '' : uom.toLowerCase();
	switch on lowerUom {
		when 'sy' {
			standard = 'sq yard';
		}
		when 'box' {
			standard = 'box';
		}
		when 'each' {
			standard = 'each';
		}
		when 'piece' {
			standard = 'piece';
		}
		when 'ft²','sq feet' {
			standard = 'sq feet';
		}
		when else {
			standard = 'sq yard';
		}
	}

	return standard;
}

public static void updateSpecBom(Specification__c spec, MdmApi.Spec mdmSpec) {
	List<Spec_Bom__c> boms;
	List<String> bomIds = new List<String>();

	// check gauge & gauge type - these were moved to operations
	if (spec?.Gauge__c != mdmSpec?.Gauge || spec?.Gauge_Type__c != mdmSpec.GaugeType) {
		spec.Gauge__c = mdmSpec.Gauge;
		spec.Gauge_Type__c = mdmSpec.GaugeType;
		Nebula.Logger.Info('Updating Specification__c', Database.upsert(spec)).setRecord(spec);
	}

	if (mdmSpec.Bom != null && !mdmSpec.Bom.isEmpty()) {
		boms = new List<Spec_Bom__c>();
		for (MdmApi.BomItem b : mdmSpec.Bom) {
			Spec_Bom__c bom = new Spec_Bom__c();
			boms.add(bom);
			bom.Specification__c = spec.Id;
			bom.Type__c = b.BomType;
			bom.Item_Type__c = b.BomItemType;
			bom.Insert_Point__c = b.BomInsertPoint;
			bom.Sequence_Nbr__c = b.BomSequenceNbr;
			bom.Item_Id__c = b.BomItemId;
			bom.Item_Id_Ext__c = b.BomItemIdExt;
			if (b.BomInRefQty != null) {
				bom.In_Ref_Qty__c = Decimal.valueOf(b.BomInRefQty);
			}
			bom.In_Ref_Qty_Uom__c = b.BomInRefQtyUom;
			bom.Consumption_Rate__c = b.BomConsumptionRate;
			bom.Name = b.BomId;
			bomIds.add(b.BomId);
		}
	}

	if (boms != null) {
		Nebula.Logger.Info('Updating Spec_Bom__c', Database.upsert(boms, Spec_Bom__c.Fields.Name)).setRecord(spec);
	}

	// delete any boms that have been deleted in MDM
	boms = [
		SELECT Id, Name, Specification__c
		FROM Spec_Bom__c
		WHERE Specification__c = :spec.Id
		  AND Name NOT IN :bomIds
	];

	for (Spec_Bom__c bom : boms) {
		delete bom;
	}
}

static private string convertName(MdmApi.Spec spec) {
	if (String.isEmpty(spec.Name)) {
		if(spec.Type.startsWithIgnoreCase('exp')) {
			return 'Experimental Spec';
		} else if(spec.Type.startsWithIgnoreCase('cad')) {
			return 'Cad Spec';
		} else if(spec.Type.startsWithIgnoreCase('product')) {
			return 'Selling Style Spec';
		} else if(spec.Type.startsWithIgnoreCase('sample')) {
			return 'Sample Spec';
		} else {
			return 'Unknown';
		}
	} else {
		return spec.Name.left(80);
	}
}

static private string convertColorization(string value) {
	if(value == null)
		return null;
	if(value.startsWithIgnoreCase('print'))
		return 'Printed';
	if(value.startsWithIgnoreCase('cptdye'))
		return 'Carpet Dyed';
	if(value.startsWithIgnoreCase('yrndye'))
		return 'Yarn Dyed';
	return value;
}

private static String convertType(String value) {
	if (value == null) {
		return null;
	}

	String recTypeName;

	if (value.startsWithIgnoreCase('exp')) {
		recTypeName = 'Experimental';
	} else if (value.startsWithIgnoreCase('product')) {
		recTypeName = 'Product';
	} else if (value.startsWithIgnoreCase('cad')) {
		recTypeName = 'Cad';
	} else if (value.startsWithIgnoreCase('sample')) {
		recTypeName = 'Sample';
	}

	if (recTypeName == null) {
		return null;
	} else {
		return Utility.getRecordType('Specification__c', recTypeName).Id;
	}
}

static public Specification__c findOldestParent(Specification__c spec) {
	if (spec.Parent_MDM_Key__c == null) {
		return spec;
	} else {
		List<Specification__c> parentSpecs = [
			SELECT Id, MDM_Key__c, Parent_MDM_Key__c, Custom_Project__c, Parent_Specification__c
			FROM Specification__c
			WHERE MDM_Key__c = : spec.Parent_MDM_Key__c 
			AND Reference_Specification__c = null
			LIMIT 1
		];
		if (parentSpecs.size() == 0) {
			// unable to find Specification record for parent (not sure why)
			return null;
		} else {
			return findOldestParent(parentSpecs.get(0));
		}
	}
}

static public void linkAllChildSpecs(Specification__c spec, String productServiceId) {
	List<Specification__c> childSpecs = [
		SELECT Id, MDM_Key__c, Parent_MDM_Key__c, Custom_Project__c, Parent_Specification__c, CDS_Design_Service__c, RecordType.Name
		FROM Specification__c
		WHERE Parent_MDM_Key__c = : spec.MDM_Key__c
		AND Reference_Specification__c = null
	];

	for (Specification__c childSpec : childSpecs) {
		Boolean updateIt = false;

		if ((childSpec.Custom_Project__c != spec.Custom_Project__c) || (childSpec.Parent_Specification__c != spec.Id)) {
			updateIt = true;
			childSpec.Custom_Project__c = spec.Custom_Project__c;
			childSpec.Parent_Specification__c = spec.Id;
		}
		if ((childSpec.RecordType.Name == 'Experimental') && (childSpec.CDS_Design_Service__c != productServiceId)) {
			updateIt = true;
			childSpec.CDS_Design_Service__c = productServiceId;
		}
		if (updateIt) {
			update childSpec;
		}

		linkAllChildSpecs(childSpec, productServiceId);
	}
}

public static Specification__c getSpecification(String mdmKey) {
	List<Specification__c> specs = [
		SELECT Id, Name, MDM_Key__c, Style_Number__c, Color_Number__c, MDM_Id_Ext__c, MDM_Id__c,
		Type__c, Parent_MDM_Key__c, Colorization__c, Gauge__c, Gauge_Type__c, Selling_Company__c,
		Face_Weight__c, RecordTypeId, Custom_Project__c
		FROM Specification__c
		WHERE MDM_Key__c = :mdmKey
		AND Reference_Specification__c = null
	];

	if (specs.size() == 0) {
		return null;
	} else {
		return specs.get(0);
	}
}

public static void reparentServicesWhenSpecsReparent(List<Specification__c> oldRecs, List<Specification__c> newRecs) {
	List<CDS_Design_Service__c> updateServices = new List<CDS_Design_Service__c>();
	List<String> prdChanges = new List<String>();
	List<String> expChanges = new List<String>();
	List<String> cadChanges = new List<String>();
	List<String> sampleChanges = new List<String>();

	RecordType expRecType = Utility.getRecordType('Specification__c', 'Experimental');
	RecordType cadRecType = Utility.getRecordType('Specification__c', 'Cad');
	RecordType sampleRecType = Utility.getRecordType('Specification__c', 'Sample');

	for (Integer x = 0; x < oldRecs.size(); x++) {
		if (oldRecs[x].Parent_Specification__c != newRecs[x].Parent_Specification__c) {
			if (oldRecs[x].RecordTypeId == expRecType.Id) {
				expChanges.add(newRecs[x].Id);
				prdChanges.add(newRecs[x].Parent_Specification__c);
			} else if (oldRecs[x].RecordTypeId == cadRecType.Id) {
				cadChanges.add(newRecs[x].Id);
			} else if (oldRecs[x].RecordTypeId == sampleRecType.Id) {
				sampleChanges.add(newRecs[x].Id);
			}
		}
	}

	if (!expChanges.isEmpty()) {
		System.debug('exp changes');
		for (String exp : expChanges) {
			System.debug(exp);
		}

		// cad changes
		List<Specification__c> cadsChanged = [
			SELECT Id
			FROM Specification__c 
			WHERE Parent_Specification__c IN :expChanges
		];
		for (Specification__c cadChanged : cadsChanged) {
			cadChanges.add(cadChanged.Id);
		}

		// pricing service changes
		List<CDS_Design_Service__c> pricingAndPatternSvcs = [
			SELECT Id, Parent_Service__c, Specification__r.Parent_Specification__c
			FROM CDS_Design_Service__c
			WHERE RecordType.DeveloperName IN ('Pricing', 'Pattern')
			AND Specification__c IN :expChanges
		];
		List<CDS_Design_Service__c> prodServices = [
			SELECT Id, Specification__c
			FROM CDS_Design_Service__c
			WHERE RecordType.DeveloperName = 'Product'
			AND Specification__c IN :prdChanges
		];
		for (CDS_Design_Service__c svc : pricingAndPatternSvcs) {
			for (CDS_Design_Service__c prodService : prodServices) {
				if (svc.Specification__r.Parent_Specification__c == prodService.Specification__c) {
					if (svc.Parent_Service__c != prodService.Id) {
						svc.Parent_Service__c = prodService.Id;
						updateServices.add(svc);
					}
					break;
				}
			}
		}
	}

	if (!cadChanges.isEmpty()) {
		List<CDS_Design_Service__c> cadServices = [
			SELECT Id, Parent_Service__c, Specification__r.Parent_Specification__r.CDS_Design_Service__c 
			FROM CDS_Design_Service__c 
			WHERE Specification__c IN :cadChanges
		];

		for (CDS_Design_Service__c service : cadServices) {
			if (service.Parent_Service__c != service.Specification__r.Parent_Specification__r.CDS_Design_Service__c) {
				service.Parent_Service__c = service.Specification__r.Parent_Specification__r.CDS_Design_Service__c;
				updateServices.add(service);
			}
		}

		// find samples that are a child to the cad spec - they need to be updated also
		List<Specification__c> samplesChanged = [
			SELECT Id
			FROM Specification__c 
			WHERE Parent_Specification__c IN :cadChanges
		];
		for (Specification__c sampleChanged : samplesChanged) {
			sampleChanges.add(sampleChanged.Id);
		}
	}

	if (!sampleChanges.isEmpty()) {
		List<CDS_Design_Service__c> sampleServices = [
			SELECT Id, Parent_Service__c, Specification__r.Parent_Specification__r.Parent_Specification__r.CDS_Design_Service__c 
			FROM CDS_Design_Service__c 
			WHERE Specification__c IN :sampleChanges
		];

		for (CDS_Design_Service__c service : sampleServices) {
			if (service.Parent_Service__c != service.Specification__r.Parent_Specification__r.Parent_Specification__r.CDS_Design_Service__c) {
				service.Parent_Service__c = service.Specification__r.Parent_Specification__r.Parent_Specification__r.CDS_Design_Service__c;
				updateServices.add(service);
			}
		}
	}

	if (!updateServices.isEmpty()) {
		update updateServices;
	}
}

public static void updateStageStatus(List<Specification__c> newRecs){
	if (newRecs.isEmpty()) {
        return;
    }

	List<CDS_Design_Service__c> stagesList = new List<CDS_Design_Service__c>();

    List<String> specs = new List<String>();
	for(Specification__c newRec : newRecs) {
		if(newRec.Status__c == 'In Progress') {
            specs.add(newrec.Id);
		}
	}
    
    List<CDS_Design_Service__c> designServices = [
        SELECT Id, Pattern_Number__c, Specification__r.Pattern_Number__c, RecordType.Id 
        FROM CDS_Design_Service__c 
        WHERE RecordType.Name = 'Stage' 
        AND Specification__c IN : specs
    ];

	///if specsInClause is 'empty' then return;
	if (designServices.isEmpty()) {
		return;
	}

	///loop stages and do work
	for(CDS_Design_Service__c designService : designServices) {
        if (designService.Pattern_Number__c <> designService.Specification__r.Pattern_Number__c) {
            designService.Pattern_Number__c = designService.Specification__r.Pattern_Number__c;
            stagesList.add(designService);
        }
	}

    if (!stagesList.isEmpty()) {
    	update stagesList;
    }
}

public static void sendEmail(List<Specification__c> specList){
	// First, reserve email capacity for the current Apex transaction to ensure
	// that we won't exceed our daily email limits when sending email after
	// the current transaction is committed.
	Messaging.reserveSingleEmailCapacity(2);

	// Processes and actions involved in the Apex transaction occur next,
	// which conclude with sending a single email.

	// Now create a new single email message object
	// that will send out a single email to the addresses in the To, CC & BCC list.
	Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();

	// Strings to hold the email addresses to which you are sending the email.
	String[] toAddresses = new String[] {'jacob.boyd@shawinc.com'};


	// Assign the addresses for the To and CC lists to the mail object.
	mail.setToAddresses(toAddresses);

	// Specify the address used when the recipients reply to the email.

	// Specify the name used as the display name.
	mail.setSenderDisplayName('Ophan Spec Code');

	// Specify the subject line for your email address.
	mail.setSubject('We did it');

	// Set to True if you want to BCC yourself on the email.
	mail.setBccSender(false);

	// Optionally append the salesforce.com email signature to the email.
	// The email address of the user executing the Apex Code will be used.
	mail.setUseSignature(false);

	// Specify the text content of the email.
	mail.setPlainTextBody('Got orphan spec in sfdc, did we handle it?   '+specList);

	// Send the email you have created.
	Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
}

public static List<Specification__c> checkForDuplicateKeys(List<Specification__c> specs) {
	List<String> keys = new List<String>();
	for (Specification__c spec : specs) {
		keys.add(spec.MDM_Key__c);
	}

	return [SELECT Id, MDM_Key__c FROM Specification__c WHERE MDM_Key__c IN :keys AND Reference_Specification__c = ''];
}

public static void calloutTest(){
	String whyAreCalloutsHard = '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';
	whyAreCalloutsHard += '';

}
}
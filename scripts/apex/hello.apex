// Use .apex files to store anonymous Apex.
// You can execute anonymous Apex in VS Code by selecting the
//     apex text and running the command:
//     SFDX: Execute Anonymous Apex with Currently Selected Text
// You can also execute the entire file by running the command:
//     SFDX: Execute Anonymous Apex with Editor Contents

String s = B2mmlTest.loadStaticResource('b2mml_Sample');
//MssB2mml.B2MML mssB2mml = (MssB2mml.B2MML) JSON.deserialize(s, MssB2mml.B2MML.class);
//public Map<String, B2mmlValue> materialDefinitionPropertyMap;
// mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap = new Map<String, MssB2mml.B2mmlValue>();
// for(MssB2mml.MaterialDefinitionProperty x : mssB2mml.masterDataProfile.materialDefinition.materialDefinitionProperty){
//     mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap.put(x.id.toLowerCase(), x.value);
// }
//System.debug(JSON.serialize(mssB2mml));

MssB2mml.B2MML x = ProcessB2MML.parseB2MML(s);
System.debug(JSON.serialize(x));
System.debug((x.masterDataProfile.materialDefinition.materialDefinitionPropertyMap.get('form').valueString));
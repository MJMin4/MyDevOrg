public with sharing class ProcessB2MML {
    public static MssB2mml.B2MML parseB2MML(String b2mmlString) {
        String s = b2mmlString.remove('b2mml:').remove('ext:').remove('mss:');
        MssB2mml.B2MML mssB2mml = (MssB2mml.B2MML) JSON.deserialize(s, MssB2mml.B2MML.class);
        mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap = new Map<String, MssB2mml.B2mmlValue>();
        for(MssB2mml.MaterialDefinitionProperty x : mssB2mml.masterDataProfile.materialDefinition.materialDefinitionProperty){
            mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap.put(x.id.toLowerCase(), x.value);
        }
        return mssB2mml;
    }
}


//String s = B2mmlTest.loadStaticResource('b2mml_Sample').remove('b2mml:').remove('ext:').remove('mss:');
//MssB2mml.B2MML mssB2mml = (MssB2mml.B2MML) JSON.deserialize(s, MssB2mml.B2MML.class);
//public Map<String, B2mmlValue> materialDefinitionPropertyMap;
//mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap = new Map<String, MssB2mml.B2mmlValue>();
//for(MssB2mml.MaterialDefinitionProperty x : mssB2mml.masterDataProfile.materialDefinition.materialDefinitionProperty){
    //mssB2mml.masterDataProfile.materialDefinition.materialDefinitionPropertyMap.put(x.id.toLowerCase(), x.value);
//}
//System.debug(JSON.serialize(mssB2mml));
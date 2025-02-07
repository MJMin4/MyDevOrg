public with sharing class MssB2mml {
    public class B2MML {
        public MasterDataProfile masterDataProfile;
    }
    public class MasterDataProfile {
        public DataType dataType;
        public MaterialDefinition materialDefinition;
        public OperationsDefinition operationsDefinition;
        public ResourceRelationshipNetwork resourceRelationshipNetwork;
    }
    public class DataType {
        public String description;
        public String id;
    }
    public class MaterialDefinition {
        public List<MaterialDefinitionProperty> materialDefinitionProperty;
        public String description;
        public String id;
        //Added for the purpose of mapping
        public Map<String, B2mmlValue> materialDefinitionPropertyMap;
        public Map<String, List<Map<String, B2mmlValue>>> materialDefinitionPropertyComplexChildMap;
    }
    public class MaterialDefinitionProperty{
        public String id;
        public B2mmlValue value;
        public List<MaterialDefinitionPropertyComplexChild> materialDefinitionPropertyComplexChild;
    }
    public class B2mmlValue{
        public String dataType;
        public String key;
        public String valueString;
        public UnitOfMeasure unitOfMeasure;
    }
    public class UnitOfMeasure{
        public String shortName;
        public String longName;
    }
    public class MaterialDefinitionPropertyComplexChild{
        public List<ChildProperty> childProperty;
        public String childType;
    }
    public class ChildProperty{
        public String id;
        public B2mmlValue value;
    }
    public class OperationsDefinition {
        public String id;
        public List<OperationsSegment> operationsSegment;
    }
    public class OperationsSegment{
        public String definitionType;
        public String description;
        public List<ParameterSpecification> parameterSpecification;
    }
    public class ParameterSpecification{
        public String description;
        public String id;
        public List<ParameterChild> parameterChild;
    }
    public class ParameterChild{
        public String id;
        public B2mmlValue value;
    }
    public class ResourceRelationshipNetwork {
        public String id;
        public List<ResourceNetworkConnection> resourceNetworkConnection;
    }
    public class ResourceNetworkConnection{
        public FromResourceReference fromResourceReference;
        public String id;
        public String resourceNetworkConnectionTypeId;
        public ToResourceReference toResourceReference;
    }
    public class FromResourceReference{
        public String id;
        public String resourceId;
        public String resourceType;
    }
    public class ToResourceReference{
        public String id;
        public String resourceId;
        public String resourceType;
    }
}
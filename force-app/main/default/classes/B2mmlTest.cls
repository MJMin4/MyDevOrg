public with sharing class B2mmlTest {
    public static String loadStaticResource(String resourceName) {
        // Create a PageReference to the static resource
        PageReference resourcePage = PageReference.forResource(resourceName);
        
        // Get the content of the static resource
        Blob resourceContent = resourcePage.getContent();
        
        // Convert the Blob to a String and return it
        return resourceContent.toString();
    }
}
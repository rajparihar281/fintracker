Feature: Image Attachment for Transactions

  As a user of the Fintracker app
  I want to attach images to my income and expense transactions
  So that I can keep receipts, bills, and invoices for reference

  Scenario: Attaching images to a new transaction
    Given I am on the payment form screen
    When I tap the "Add Images" button
    And I select multiple images from my device
    Then the selected images should appear as thumbnails
    And I should be able to preview the images by tapping on them
    And I should be able to remove images by tapping the close button

  Scenario: Viewing attached images in transaction list
    Given I have a transaction with attached images
    When I view the transaction in the payments list
    Then I should see an image icon with the count of attached images
    When I tap on the image icon
    Then I should be able to view all attached images in full screen

  Scenario: Editing transaction with existing images
    Given I have a transaction with attached images
    When I edit the transaction
    Then I should see the previously attached images
    And I should be able to add more images
    And I should be able to remove existing images
    And the changes should be saved when I update the transaction
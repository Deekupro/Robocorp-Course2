*** Settings ***
Documentation       This automation is designed around the tips told in the Course 2 material.
...                 Process firstly creates and cleans the working directrory where images and PDFs will 
...                 be saved. Next we download the orders file and start to process that. 
...                 We open web browser with the given URL of the ordering system and fill it out with
...                 the given details. After this we take a screenshot of the robot image and save the 
...                 receipt as a PDF. After this we embed the image to the PDF file. We repeat these steps
...                 for every item in the file and when all items have been processed we put all the PDFs
...                 in to a ZIP file.
Library    RPA.Browser.Selenium
Library    RPA.HTTP
Library    RPA.Tables
Library    RPA.Cloud.Azure
Library    RPA.PDF
Library    RPA.Database
Library    Screenshot
Library    RPA.FileSystem
Library    RPA.Archive


*** Variables ***
${img_folder}            ${OUTPUT_DIR}${/}Images
${pdf_folder}            ${OUTPUT_DIR}${/}PDF
${zip_file}              ${OUTPUT_DIR}${/}pdf_archive.zip
${order_another}         //*[@id="order-another"]

${orders_file_url}       https://robotsparebinindustries.com/orders.csv
${robot_ordering_url}    https://robotsparebinindustries.com/#/robot-order


*** Tasks ***
 Create orders from csv file
    Directory Cleanup
    Download orders file
    Open browser to create orders
    ${orders} =    Read table from CSV    orders.csv    header=True
    FOR    ${orders}    IN    @{orders}
        Set Local Variable      ${order_num}    ${orders}[Order number]
        
        Fill and submit the form for one robot    ${orders}
        Wait Until Keyword Succeeds    10x    1s    Submit order
        ${orderid}    ${img_filename}=    Take screenshot of robot
        ${PDF_filename}=    Store receipt as PDF    ${order_id}
        Embed screenshot to PDF    ${PDF_filename}    ${img_filename}
        Click order another
    END    
    Create zip archive
    [Teardown]    Close browser

*** Keywords ***
Directory Cleanup
    # Here we create directory for images and PDFs, after creation we clean the directory.
    Log To console      Cleaning up content from previous test runs

    Create Directory    ${img_folder}
    Create Directory    ${pdf_folder}

    Empty Directory     ${img_folder}
    Empty Directory     ${pdf_folder}

Download orders file
    # This downloads the orders file and overwrites it if it already exists.
    Download    ${orders_file_url}    overwrite=True
Open browser to create orders
    # This opens the robot ordering site.
    Open Available Browser    ${robot_ordering_url}

Close browser
    # This closes all browser instances opened by the process.
    Close All Browsers


Fill and submit the form for one robot   
    [Arguments]    ${orders}
    
    #Here we setup local variables used as input in the later part of this task.
    Set Local Variable    ${head}                     ${orders}[Head]
    Set Local Variable    ${body}                     ${orders}[Body]
    Set Local Variable    ${legs}                     ${orders}[Legs]
    Set Local Variable    ${address}                  ${orders}[Address]
    
    #Here we set local variables for the elements in the web page so the task is easier to read.
    Set Local Variable    ${popup_button_OK}    //*[@id="root"]/div/div[2]/div/div/div/div/div/button[1]
    Set Local Variable    ${textfield_head}           //*[@id="head"]
    Set Local Variable    ${multibutton_body}         //*[@id="id-body-${body}"]
    Set Local Variable    ${textfield_legs}           //*[@placeholder="Enter the part number for the legs"]
    Set Local Variable    ${textfield_address}        //*[@id="address"]
    Set Local Variable    ${button_preview}           //*[@id="preview"]
    
    #Check that popup is visible and click it.
    Wait Until Element Is Visible    ${popup_button_OK}
    Click Button                     ${popup_button_OK}
    
    #Check that element is visible and select wich type of head the robot needs.
    Wait Until Element Is Visible    ${textfield_head}
    Select From List By Value        ${textfield_head}        ${head}
    
    #Check that button is visible and select the type of body the robot needs.
    Wait Until Element Is Visible    ${multibutton_body}
    Click Button                     ${multibutton_body}
    
    #Check that textfield is visible and write the type of legs the robot needs.
    Wait Until Element Is Visible    ${textfield_legs}
    Input Text                       ${textfield_legs}        ${legs} 
    
    #Check that textfield is visible and write the address the robot is shipped to.
    Wait Until Element Is Visible    ${textfield_address}
    Input Text                       ${textfield_address}     ${address} 
    
    Wait Until Element Is Visible    ${button_preview}
    Click Button                     ${button_preview}
    
    #This static sleep is for the web page to load the image.
    Sleep    1


Submit order
    #Set Order button element as a local variable
    Set Local Variable             ${button_order}    //*[@id="order"]
    
    #Click Order button and check that the process moved to the next page which contains 
    #order another button.
    Click Button                   ${button_order}
    Page Should Contain Element    ${order_another}



Click order another
    #Click button order another    
    Click Button      ${order_another}


Take screenshot of robot
    #Set robot image on the web page as a local variable and wait for it to be visible
    Set Local Variable         ${image_preview_robot}      //*[@id="robot-preview-image"]
    Wait Until Element Is Visible                          ${image_preview_robot}

    #Get order id as a variable ${orderid}
    ${orderid}=           Get Text                         //*[@id="receipt"]/p[1]
    
    #Set local variable for image file and screenshot the preview image on the web page and save it.
    Set Local Variable    ${local_img_filename}            ${img_folder}/Ordered_robot_ss${orderid}.png
    Screenshot            ${image_preview_robot}           ${local_img_filename}

    #Return the order id and image file name.
    [RETURN]    ${orderid}    ${local_img_filename}


Store receipt as PDF
    [Arguments]    ${Order_num_receipt}     #Get the receipt id from main process.
    
    # Set receipt element as a local variable.
    Set Local Variable    ${receipt}               //*[@id="receipt"]
    
    #Wait until receipt element is visible and save the element as a variable ${Html_robot}.
    Wait Until Element Is Visible                  ${receipt}
    ${Html_robot}=    Get Element Attribute        ${receipt}    outerHTML

    #Set PDF filename as a local variable.
    Set Local Variable    ${local_PDF_filename}    ${pdf_folder}${/}Ordered_robot${Order_num_receipt}.pdf
    
    #The receipt is put to a pdf in this part.
    Html To Pdf           ${Html_robot}            ${local_PDF_filename}

    [RETURN]    ${local_PDF_filename}  #Return the filename to main process.


Embed screenshot to PDF
    [Arguments]    ${PDF_File}    ${img_file}    #Get image and PDF file names.
    
    #Open the PDF file.
    Open Pdf       ${PDF_File}
    
    #Create a list that includes the right image file.
    ${ss_of_robot}=    Create List        ${img_file}:x=0,y=0

    #Add the image list to the pdf file. Here was a problem when trying to put the image on the same page
    #because it would overwrite the receipt. I fixed this by putting the image on the second page.
    Add Files To pdf    ${ss_of_robot}    ${PDF_File}    ${True}

    #Close the PDF file
    Close Pdf           ${PDF_File}


Create zip archive
    #Create zip folder with all of the order PDFs.
    Archive Folder With Zip    ${pdf_folder}    ${zip_file}   recursive=True  include=*.pdf
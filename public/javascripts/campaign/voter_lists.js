var VoterLists = function(){
  document.getElementById('upload_datafile').addEventListener('change', this.validate_csv_file, false);


  $("#file_upload_submit").click(function(){
  if ($("#voter_list_name").val().trim() == ""){
    alert("Please enter a name for the list to be uploaded.");
    return false;
  }
  if ($("#voter_list_name").val().trim().length <= 3){
    alert("Voter List name is too short. Please enter more than 3 characters.");
    return false;
  }
  var selected_mapping = []
  $(".select-column-mapping").each(function( index ) {
    selected_mapping.push($(this).val());
  });

  if($.inArray("Phone", selected_mapping) == -1){
    alert("Please choose map a column to the Phone field before uploading.");
    return false;
  }

  if($.inArray("CustomID", selected_mapping) == -1){
    return confirm("Are you sure you want to upload this list without an ID field? You will not be able to update these leads in the future.");
  }


  return true

  });
}


VoterLists.prototype.validate_csv_file = function(evt){
  $("#column_headers").empty();
  $("#voter_upload").hide();
  var file = evt.target.files[0];
  var file_name = file.name;
  var extension = file_name.split(".").pop().toLowerCase();
  var separator = extension == "csv" ? "," : "\t";
  if ($.inArray(extension, ["csv", "txt"]) == -1){
     alert("Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.");
   return false;
  }

  var options = {
    data: {},
    success:  function(data) {
    $('#column_headers').html(data);
    $("#list_name").show();
    $("#voter_list_separator").val(separator)
    $("#voter_upload").show();
    $('#voter_list_upload').attr('action', "/client/campaigns/"+$('#campaign_id').val()+"/voter_lists");

    $("#column_headers select").change(function() {
      if($(this).val() == "CustomID"){
        var id_mapped = confirm("The ID field must be unique for every lead in your campaign. If two leads have the same IDs, the newer one will overwrite the older one. Are you sure you want to map this header the ID field?");
        if(!id_mapped){$(this).val("");}
      }
      if ($(this).val() == 'custom') {
        var newField = prompt('Enter the name of field to create:');
        if (newField) {
          $(this).children("option[value='custom']").before("<option value='" + newField + "'>" + newField + "</option>");
          $(this).val(newField);
        }
      }
    });
  }
  };
    $('#voter_list_upload').attr('action', "/client/campaigns/"+$('#campaign_id').val()+"/voter_lists/column_mapping");
    $('#voter_list_upload').submit(function() {

      $('#column_headers').html("<p>Please wait while your file is being uploaded...</p>");
        $(this).ajaxSubmit(options);
        return false;
    });
    $("#voter_list_upload").trigger("submit");
    $("#voter_list_upload").unbind("submit");
}

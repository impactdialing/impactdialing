var VoterLists = function(){
  document.getElementById('upload_datafile').addEventListener('change', this.validate_csv_file, false);
  $("#file_upload_submit").click(function(){
  if ($("#voter_list_name").val().trim() == ""){
    alert("Please enter a name for the list to be uploaded.");
    return false;
  }
  if ($("#voter_list_name").val().trim().length <= 3){
    alert("Voter List name is too short. Please enter more than 3 characters");
    return false;
  }
  return true

  });
}


VoterLists.prototype.validate_csv_file = function(evt){
  $("#column_headers").empty();
  $("#voter_upload").hide();
  var file = evt.target.files[0];
  var file_name = file.name;
  var extension = file_name.split(".").pop();
  if ($.inArray(extension, ["csv", "txt"]) == -1){
     alert("Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.");
   return false;
  }
  else {
  var reader = new FileReader();
  reader.onload = function(theFile) {
    var file_contents = theFile.target.result;
    var separator = extension == "csv" ? "," : "\t";
    var csv_array = $.csv2Array(file_contents, {separator: separator})
    var csv_column_headers = csv_array[0];
    var csv_column_data = csv_array[1];
    $.get("/client/campaigns/"+$('#campaign_id').val()+"/voter_lists/column_mapping", {headers: csv_column_headers, first_data_row: csv_column_data, extension: extension},function(data) {
      $('#column_headers').html(data);
      $("#voter_list_separator").val(separator)
      $("#list_name").show();
      $("#voter_upload").show();
  });

  };
  reader.readAsText(file);
  }
}




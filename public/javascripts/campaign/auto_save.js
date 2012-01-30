$(document).ready(function(){
    	$("#file_upload_submit").live('click', function() {
		$.ajax({
			url : $("#callerForm").attr("action"),
			data : $("#callerForm").serialize(),
			type : "POST",
			success : function(response){
				if(response.match(/^<!DOCTYPE html>/)){
					$("#new_voter_list").submit();
				}
				else{
					$('#validationError').html(response)
				}
			},
			error: function(response){
				$('#validationError').html(response['responseText'])
			}

		});
	});
})

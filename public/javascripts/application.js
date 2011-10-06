// Place your application-specific JavaScript functions and classes here
// This file is automatically included by javascript_include_tag :defaults

$(document).ajaxSend(function(e, xhr, options) {
  var token = $("meta[name='csrf-token']").attr("content");
  xhr.setRequestHeader("X-CSRF-Token", token);
});

function remove_fields(link) {
    $(link).previous("input[type=hidden]").value = "1";
    $(link).up(".fields").hide();
}

function add_fields(link, association, content) {
    var new_id = new Date().getTime();
    var regexp = new RegExp("new_" + association, "g");
    $(link).up().insert({
        before: content.replace(regexp, new_id)
    });
}

function delete_entity(form_id){
	if (confirm('Are you sure?'))
		$(form_id).submit();
}

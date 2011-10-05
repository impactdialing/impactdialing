delete_blocked_number = function(form_id) {
	if (confirm('Are you sure?'))
		$(form_id).submit();
}
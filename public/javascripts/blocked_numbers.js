delete_blocked_number = function(form_id) {
	if (confirm('Are you sure you want to remove this number from the Do Not Call list?'))
		$(form_id).submit();
}
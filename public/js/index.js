$(function() {
    $('#name').on('input propertychange paste', function() {
        var name = $('#name').val();
        if (name) {
            $('#links').show();
            $('.name').each(function() {
                var link = $(this).attr('data-format').replace('{name}', name);
                $(this).attr('href', link);
                $(this).children('span').text(name);
            });
        } else {
            $('#links').hide();
        }
    });
    $('#name').focus();
});

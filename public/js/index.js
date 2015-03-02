$(function() {
    function update() {
        var name = $('#name').val();
        var id = $('#id').val();
        if (name) {
            $('#links').show();
            $('.resource').each(function() {
                var link = $(this).attr('data-format').replace('{name}', name)
                                                      .replace('{id}', id);
                $(this).attr('href', link);
                $(this).children('span.name').text(name);
                $(this).children('span.id').text(id);
            });
        } else {
            $('#links').hide();
        }
    }

    $('#name').on('input propertychange paste', update);
    $('#id').on('input propertychange paste', update);
    $('#name').focus();
});

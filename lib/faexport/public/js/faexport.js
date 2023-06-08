'use strict';

$(function() {
    function linkFormat(dataFormat, name, id, cookie_a, cookie_b) {
        const base = window.location.origin;
        const cookie_base = `${window.location.protocol}//ab:${cookie_a};${cookie_b}@${window.location.host}`;
        return dataFormat
            .replace('{name}', name)
            .replace('{id}', id)
            .replace('{base}', base)
            .replace('{cookie_base}', cookie_base);
    }

    function showLink(linkElement, name, id, cookie_a, cookie_b) {
        console.log("Show link");
        const dataFormat = linkElement.attr('data-format');
        const address = linkFormat(dataFormat, encodeURI(name), id, cookie_a, cookie_b);
        const text = linkFormat(dataFormat, name, id, cookie_a, cookie_b);
        linkElement.removeClass("disabled");
        linkElement.attr('href', address);
        linkElement.text(text);
    }

    function hideLink(linkElement) {
        console.log("Hide link");
        const base = window.location.origin;
        const cookie_base = `${window.location.protocol}//ab:{cookie_a};{cookie_b}@${window.location.host}`
        linkElement.addClass("disabled");
        linkElement.removeAttr('href');
        linkElement.text(linkElement.attr('data-format')
            .replace("{base}", base)
            .replace("{cookie_base}", cookie_base)
        );
    }

    function update() {
        console.log("Update");
        const name = $('#boxes #name').val();
        const id = $('#boxes #id').val();
        const cookie_a = $('#boxes_auth #cookie_a').val();
        const cookie_b = $('#boxes_auth #cookie_b').val();
        $('.resource').each(function() {
            const data_format = $(this).attr('data-format');
            const checks = [
                !data_format.includes("{name}") || Boolean(name),
                !data_format.includes("{id}") || Boolean(id),
                !data_format.includes("{cookie_base}") || Boolean(cookie_a && cookie_b),
            ];
            checks.every(Boolean) ? showLink($(this), name, id, cookie_a, cookie_b) : hideLink($(this));
        });
    }

    $('#name').on('input propertychange paste', update);
    $('#id').on('input propertychange paste', update);
    $('#cookie_a').on('input propertychange paste', update);
    $('#cookie_b').on('input propertychange paste', update);
    $('#name').focus();
    update();
});

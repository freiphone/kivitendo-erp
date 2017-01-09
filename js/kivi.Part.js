namespace('kivi.Part', function(ns) {

  ns.open_history_popup = function() {
    var id = $("#part_id").val();
    kivi.popup_dialog({
      url:    'controller.pl?action=Part/history&part.id=' + id,
      dialog: { title: kivi.t8('History') },
    });
  }

  ns.save = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/save' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.use_as_new = function() {
    var oldid = $("#part_id").val();
    $('#ic').attr('action', 'controller.pl?action=Part/use_as_new&old_id=' + oldid);
    $('#ic').submit();
  };

  ns.delete = function() {
    var data = $('#ic').serializeArray();
    data.push({ name: 'action', value: 'Part/delete' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.reformat_number = function(event) {
    $(event.target).val(kivi.format_amount(kivi.parse_amount($(event.target).val()), -2));
  };

  ns.set_tab_active_by_index = function (index) {
    $("#ic_tabs").tabs({active: index})
  };

  ns.set_tab_active_by_name= function (name) {
    var index = $('#ic_tabs a[href=#' + name + ']').parent().index();
    ns.set_tab_active_by_index(index);
  };

  ns.reorder_items = function(order_by) {
    var dir = $('#' + order_by + '_header_id a img').attr("data-sort-dir");
    var part_type = $("#part_part_type").val();

    var data;
    if (part_type === 'assortment') {
      $('#assortment thead a img').remove();
      data = $('#assortment :input').serializeArray();
    } else if ( part_type === 'assembly') {
      $('#assembly thead a img').remove();
      data = $('#assembly :input').serializeArray();
    };

    var src;
    if (dir == "1") {
      dir = "0";
      src = "image/up.png";
    } else {
      dir = "1";
      src = "image/down.png";
    }

    $('#' + order_by + '_header_id a').append('<img border=0 data-sort-dir=' + dir + ' src=' + src + ' alt="' + kivi.t8('sort items') + '">');

    data.push({ name: 'action',    value: 'Part/reorder_items' },
              { name: 'order_by',  value: order_by             },
              { name: 'part_type', value: part_type            },
              { name: 'sort_dir',  value: dir                  });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assortment_recalc = function() {
    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/update_item_totals' },
              { name: 'part_type', value: 'assortment'                   });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.assembly_recalc = function() {
    var data = $('#assembly :input').serializeArray();
    data.push( { name: 'action',    value: 'Part/update_item_totals' },
               { name: 'part_type', value: 'assembly'                        });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.set_assortment_sellprice = function() {
    $("#part_sellprice_as_number").val($("#items_sellprice_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_sellprice_as_number").focus();
  };

  ns.set_assortment_lsg_sellprice = function() {
    $("#items_lsg_sellprice_sum_basic").closest('td').find('input').val($("#items_lsg_sellprice_sum").html());
  };

  ns.set_assortment_douglas_sellprice = function() {
    $("#items_douglas_sellprice_sum_basic").closest('td').find('input').val($("#items_douglas_sellprice_sum").html());
  };

  ns.set_assortment_lastcost = function() {
    $("#part_lastcost_as_number").val($("#items_lastcost_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_lastcost_as_number").focus();
  };

  ns.set_assembly_sellprice = function() {
    $("#part_sellprice_as_number").val($("#items_sellprice_sum").html());
    // ns.set_tab_active_by_name('basic_data');
    // $("#part_sellprice_as_number").focus();
  };

  ns.renumber_positions = function() {
    var part_type = $("#part_part_type").val();
    var rows;
    if (part_type === 'assortment') {
      rows = $('.assortment_item_row [name="position"]');
    } else if ( part_type === 'assembly') {
      rows = $('.assembly_item_row [name="position"]');
    };
    $(rows).each(function(idx, elt) {
      $(elt).html(idx+1);
      var row = $(elt).closest('tr');
      if ( idx % 2 === 0 ) {
        if ( row.hasClass('listrow1') ) {
          row.removeClass('listrow1');
          row.addClass('listrow0');
        };
      } else {
        if ( row.hasClass('listrow0') ) {
          row.removeClass('listrow0');
          row.addClass('listrow1');
        };
      };
    });
  };

  ns.delete_item_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();
    var part_type = $("#part_part_type").val();
    ns.renumber_positions();
    if (part_type === 'assortment') {
      ns.assortment_recalc();
    } else if ( part_type === 'assembly') {
      ns.assembly_recalc();
    };
  };

  ns.add_assortment_item = function() {
    if ($('#add_assortment_item_id').val() === '') return;

    $('#row_table_id thead a img').remove();

    var data = $('#assortment :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assortment_item' },
              { name: 'part.id', value: $('#part_id').val()       },
              { name: 'part.part_type', value: 'assortment'       });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.add_assembly_item = function() {
    if ($('#add_assembly_item_id').val() === '') return;

    var data = $('#assembly :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_assembly_item' },
              { name: 'part.id', value: $("#part_id").val()     },
              { name: 'part.part_type', value: 'assortment'     });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.redisplay_items = function(data) {
    var old_rows;
    var part_type = $("#part_part_type").val();
    if (part_type === 'assortment') {
      old_rows = $('.assortment_item_row').detach();
    } else if ( part_type === 'assembly') {
      old_rows = $('.assembly_item_row').detach();
    };
    var new_rows = [];
    $(data).each(function(idx, elt) {
      new_rows.push(old_rows[elt.old_pos - 1]);
    });
    if (part_type === 'assortment') {
      $(new_rows).appendTo($('#assortment_items'));
    } else if ( part_type === 'assembly') {
      $(new_rows).appendTo($('#assembly_items'));
    };
    ns.renumber_positions();
  };

  ns.focus_last_assortment_input = function () {
    $("#assortment_items tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  ns.focus_last_assembly_input = function () {
    $("#assembly_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };

  ns.show_multi_items_dialog = function(part_type,part_id) {

    $('#row_table_id thead a img').remove();

    kivi.popup_dialog({
      url: 'controller.pl?action=Part/show_multi_items_dialog',
      data: { callback:         'Part/add_multi_' + part_type + '_items',
              callback_data_id: 'ic',
              'part.part_type': part_type,
              'part.id'       : part_id,
            },
      id: 'jq_multi_items_dialog',
      dialog: {
        title: kivi.t8('Add multiple items'),
        width:  800,
        height: 800
      }
    });
    return true;
  };

  ns.close_multi_items_dialog = function() {
    $('#jq_multi_items_dialog').dialog('close');
  };


  // makemodel
  ns.makemodel_renumber_positions = function() {
    $('.makemodel_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
  };

  ns.delete_makemodel_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.makemodel_renumber_positions();
  };

  ns.add_makemodel_row = function() {
    if ($('#add_makemodelid').val() === '') return;

    var data = $('#makemodel_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_makemodel_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_makemodel_input = function () {
    $("#makemodel_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };


  // customerprice
  ns.customerprice_renumber_positions = function() {
    $('.customerprice_row [name="position"]').each(function(idx, elt) {
      $(elt).html(idx+1);
    });
  };

  ns.delete_customerprice_row = function(clicked) {
    var row = $(clicked).closest('tr');
    $(row).remove();

    ns.customerprice_renumber_positions();
  };

  ns.add_customerprice_row = function() {
    if ($('#add_customerpriceid').val() === '') return;

    var data = $('#customerprice_table :input').serializeArray();
    data.push({ name: 'action', value: 'Part/add_customerprice_row' });

    $.post("controller.pl", data, kivi.eval_json_result);
  };

  ns.focus_last_customerprice_input = function () {
    $("#customerprice_rows tr:last").find('input[type=text]').filter(':visible:first').focus();
  };


  ns.reload_bin_selection = function() {
    $.post("controller.pl", { action: 'Part/warehouse_changed', warehouse_id: function(){ return $('#part_warehouse_id').val() } },   kivi.eval_json_result);
  }

  ns.calcReorderLevel = function() {
    var leadtime = Math.floor(Number(kivi.parse_amount($('#part_leadtime_as_number').val()))) + 7 ;
    var consume  = Number(kivi.parse_amount($('#part_consume_as_number').val())) / 30.0 ;
    var rop      = Number(kivi.parse_amount($('#part_rop_as_number').val()));
    $('#reorder_level').text(kivi.format_amount(rop + (consume * leadtime),2)) ;
    return false;
  };

  ns.parttypeChanged = function(__event) {
    var ls = document.getElementById("l_service");
    var lp = document.getElementById("l_part");
    var la = document.getElementById("l_assembly");
    var lt = document.getElementById("l_assortment");
    var os = ( ls.checked && !lp.checked && !la.checked && !lt.checked) ? 'hidden':'visible';
    var ns = ( !ls.checked && !lp.checked && la.checked && !lt.checked) ? 'hidden':'visible';
    document.getElementById("warehouse_tr").style.visibility = os;
    document.getElementById("no_service").style.visibility   = os;
    document.getElementById("no_service1").style.visibility  = os;
    document.getElementById("no_service2").style.visibility  = os;
    document.getElementById("no_service3").style.visibility  = os;
    document.getElementById("no_assembly1").style.visibility = ns;
    document.getElementById("no_assembly2").style.visibility = ns;
    document.getElementById("is_assembly").style.visibility  = la.checked ?'visible':'hidden';
  };

  ns.inline_report = function(target, source, data){
    $.ajax({
      url:        source,
      success:    function (rsp) {
        $(target).html(rsp);
        $(target).find('.paginate').find('a').click(function(event){ ns.redirect_event(event, target) });
        $(target).find('a.report-generator-header-link').click(function(event){ ns.redirect_event(event, target) });
      },
      data:       data,
    });
  };

  ns.redirect_event = function(event, target){
    event.preventDefault();
    ns.inline_report(target, event.target + '', {});
  };

  ns.assemblyMaxlevelChanged = function(value,partid,direction) {
    var elem = document.getElementsByName("report_generator_hidden_maxlevel");
    if ( elem && elem[0] ) {
      elem[0].value = value;
    }
    if ( direction == 1 ) {
      ns.inline_report('#listcomponents', 'controller.pl',
                       { action: 'Assembly/ajax_listcomponents', maxlevel: value, object_id: partid, inline: 1 });
    }
    else {
      ns.inline_report('#listassemblies', 'controller.pl',
                       { action: 'Assembly/ajax_listassemblies', maxlevel: value, object_id: partid, inline: 1 });
    }
    return false;
  };

  $(function(){

    // assortment
    // TODO: allow units for assortment items
    $('#add_assortment_item_id').on('set_item:PartPicker', function(e,o) { $('#add_item_unit').val(o.unit) });

    $('#ic').on('focusout', '.reformat_number', function(event) {
       ns.reformat_number(event);
    });

    $('#ic5').on('focusout', '.calc_reorder', function(event) {
       ns.calcReorderLevel();
    });

    $('.calc_reorder').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        ns.calcReorderLevel();
        return false;
      }
    });

    ns.calcReorderLevel();

    $('.add_assortment_item_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        if ($("input[name='add_items[+].parts_id']").val() != '' ) {
          kivi.Part.show_multi_items_dialog("assortment");
         // ns.add_assortment_item();
        };
        return false;
      }
    });

    $('.add_assembly_item_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        if ($("input[name='add_items[+].parts_id']").val() != '' ) {
          kivi.Part.show_multi_items_dialog("assortment");
          // ns.add_assembly_item();
        }
        return false;
      }
    });

    $('.add_makemodel_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        ns.add_makemodel_row();
        return false;
      }
    });

    $('.add_customerprice_input').keydown(function(event) {
      if(event.keyCode == 13) {
        event.preventDefault();
        ns.add_customerprice_row();
        return false;
      }
    });

    $('#part_warehouse_id').change(kivi.Part.reload_bin_selection);

  });
})

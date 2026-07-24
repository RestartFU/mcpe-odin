package gt_nbt

import "core:testing"
import mcpe_runtime "mcpe:runtime"

@(test)
dump_matches_upstream_layout :: proc(t: ^testing.T) {
    list := value_list(
        .Int,
        []Value{value_int(1), value_int(-2), value_int(3)},
    )
    root := value_compound([]Named_Value{named_value("Values", list)})
    defer destroy_value(&root)
    data, marshal_err := marshal(&root, .Little_Endian)
    testing.expect(t, marshal_err == nil)
    if marshal_err != nil {
        mcpe_runtime.destroy_error(marshal_err)
        return
    }
    defer delete(data)

    text, dump_err := dump(data, .Little_Endian)
    testing.expect(t, dump_err == nil)
    if dump_err != nil {
        mcpe_runtime.destroy_error(dump_err)
        return
    }
    defer delete(text)
    expected :=
        "TAG_Compound({\n" +
        "\t'Values': TAG_List<TAG_Int>({\n" +
        "\t\t1,\n" +
        "\t\t-2,\n" +
        "\t\t3,\n" +
        "\t}),\n" +
        "})"
    testing.expect_value(t, text, expected)
}

@(test)
dump_rejects_non_compound_roots :: proc(t: ^testing.T) {
    root := Value{tag = .Int, int = 42}
    data, marshal_err := marshal(&root, .Little_Endian)
    testing.expect(t, marshal_err == nil)
    if marshal_err != nil {
        mcpe_runtime.destroy_error(marshal_err)
        return
    }
    defer delete(data)
    text, err := dump(data, .Little_Endian)
    testing.expect_value(t, text, "")
    testing.expect(t, err != nil)
    if err != nil {
        testing.expect_value(
            t,
            err.kind,
            mcpe_runtime.Error_Kind.Invalid_Argument,
        )
        mcpe_runtime.destroy_error(err)
    }
}

@(test)
dump_matches_upstream_list_type_inference :: proc(t: ^testing.T) {
    inner := new_value(
        value_list(.Int, []Value{value_int(1)}),
    )
    nested_children := make([]^Value, 1)
    nested_children[0] = inner
    nested := Value{
        tag = .List,
        list_type = .List,
        list = nested_children,
    }
    empty_string := Value{tag = .List, list_type = .String}
    empty_int := Value{tag = .List, list_type = .Int}
    root := value_compound(
        []Named_Value{
            named_value("Nested", nested),
            named_value("EmptyString", empty_string),
            named_value("EmptyInt", empty_int),
        },
    )
    defer destroy_value(&root)
    data, marshal_err := marshal(&root, .Little_Endian)
    testing.expect(t, marshal_err == nil)
    if marshal_err != nil {
        mcpe_runtime.destroy_error(marshal_err)
        return
    }
    defer delete(data)

    text, dump_err := dump(data, .Little_Endian)
    testing.expect(t, dump_err == nil)
    if dump_err != nil {
        mcpe_runtime.destroy_error(dump_err)
        return
    }
    defer delete(text)
    expected :=
        "TAG_Compound({\n" +
        "\t'Nested': TAG_List<TAG_List<TAG_Int>>({\n" +
        "\t\t{\n" +
        "\t\t\t1,\n" +
        "\t\t},\n" +
        "\t}),\n" +
        "\t'EmptyString': TAG_List<nil>({\n" +
        "\t}),\n" +
        "\t'EmptyInt': TAG_List<TAG_Int>({\n" +
        "\t}),\n" +
        "})"
    testing.expect_value(t, text, expected)
}

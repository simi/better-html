require 'test_helper'

module BetterHtml
  class ParserTest < ActiveSupport::TestCase
    test "consume cdata nodes" do
      tree = BetterHtml::Parser.new("<![CDATA[ foo ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::CData, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated cdata nodes are consumed until end" do
      tree = BetterHtml::Parser.new("<![CDATA[ foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::CData, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume cdata with interpolation" do
      tree = BetterHtml::Parser.new("<![CDATA[ foo <%= bar %> baz ]]>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::CData, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment nodes" do
      tree = BetterHtml::Parser.new("<!-- foo -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Comment, tree.nodes.first.class
      assert_equal [" foo "], tree.nodes.first.content_parts.map(&:text)
    end

    test "unterminated comment nodes are consumed until end" do
      tree = BetterHtml::Parser.new("<!-- foo")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Comment, tree.nodes.first.class
      assert_equal [" foo"], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume comment with interpolation" do
      tree = BetterHtml::Parser.new("<!-- foo <%= bar %> baz -->")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Comment, tree.nodes.first.class
      assert_equal [" foo ", "<%= bar %>", " baz "], tree.nodes.first.content_parts.map(&:text)
    end

    test "consume tag nodes" do
      tree = BetterHtml::Parser.new("<div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal false, tree.nodes.first.self_closing?
    end

    test "consume tag nodes with solidus" do
      tree = BetterHtml::Parser.new("</div>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal true, tree.nodes.first.closing?
    end

    test "sets self_closing when appropriate" do
      tree = BetterHtml::Parser.new("<div/>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
      assert_equal true, tree.nodes.first.self_closing?
    end

    test "consume tag nodes until name ends" do
      tree = BetterHtml::Parser.new("<div/>")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)

      tree = BetterHtml::Parser.new("<div ")
      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["div"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag nodes with interpolation" do
      tree = BetterHtml::Parser.new("<ns:<%= name %>-thing>")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Element, tree.nodes.first.class
      assert_equal ["ns:", "<%= name %>", "-thing"], tree.nodes.first.name_parts.map(&:text)
    end

    test "consume tag attributes nodes unquoted value" do
      tree = BetterHtml::Parser.new("<div foo=bar>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Parser::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Parser::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ["bar"], attribute.value_parts.map(&:text)
    end

    test "consume attributes without name" do
      tree = BetterHtml::Parser.new("<div 'thing'>")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Parser::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Parser::Attribute, attribute.class
      assert_predicate attribute.name, :empty?
      assert_equal ["'", "thing", "'"], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes quoted value" do
      tree = BetterHtml::Parser.new("<div foo=\"bar\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Parser::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Parser::Attribute, attribute.class
      assert_equal ["foo"], attribute.name_parts.map(&:text)
      assert_equal ['"', "bar", '"'], attribute.value_parts.map(&:text)
    end

    test "consume tag attributes nodes interpolation in name and value" do
      tree = BetterHtml::Parser.new("<div data-<%= foo %>=\"some <%= value %> foo\">")

      assert_equal 1, tree.nodes.size
      tag = tree.nodes.first
      assert_equal BetterHtml::Parser::Element, tag.class
      assert_equal 1, tag.attributes.size
      attribute = tag.attributes.first
      assert_equal BetterHtml::Parser::Attribute, attribute.class
      assert_equal ["data-", "<%= foo %>"], attribute.name_parts.map(&:text)
      assert_equal ['"', "some ", "<%= value %>", " foo", '"'], attribute.value_parts.map(&:text)
    end

    test "consume text nodes" do
      tree = BetterHtml::Parser.new("here is <%= some %> text")

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template parsing works" do
      tree = BetterHtml::Parser.new("here is <%= some %> text", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Text, tree.nodes.first.class
      assert_equal ["here is ", "<%= some %>", " text"], tree.nodes.first.content_parts.map(&:text)
    end

    test "javascript template does not consume html tags" do
      tree = BetterHtml::Parser.new("<div <%= some %> />", template_language: :javascript)

      assert_equal 1, tree.nodes.size
      assert_equal BetterHtml::Parser::Text, tree.nodes.first.class
      assert_equal ["<div ", "<%= some %>", " />"], tree.nodes.first.content_parts.map(&:text)
    end

    test "lodash template parsing works" do
      tree = BetterHtml::Parser.new('<div class="[%= foo %]">', template_language: :lodash)

      assert_equal 1, tree.nodes.size
      node = tree.nodes.first
      assert_equal BetterHtml::Parser::Element, node.class
      assert_equal "div", node.name
      assert_equal 1, node.attributes.size
      attribute = node.attributes.first
      assert_equal "class", attribute.name
      assert_equal [:attribute_quoted_value_start, :expr_literal,
        :attribute_quoted_value_end], attribute.value_parts.map(&:type)
      assert_equal ["\"", "[%= foo %]", "\""], attribute.value_parts.map(&:text)
    end
  end
end

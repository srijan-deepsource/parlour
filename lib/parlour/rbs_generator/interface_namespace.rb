# typed: true
module Parlour
  class RbsGenerator < Generator
    # Represents an interface definition.
    class InterfaceNamespace < Namespace
      extend T::Sig

      Child = type_member(fixed: RbsObject)

      sig do
        override.params(
          indent_level: Integer,
          options: Options
        ).returns(T::Array[String])
      end
      # Generates the RBS lines for this interface.
      #
      # @param indent_level [Integer] The indentation level to generate the lines at.
      # @param options [Options] The formatting options to use.
      # @return [Array<String>] The RBS lines, formatted as specified.
      def generate_rbs(indent_level, options)        
        lines = generate_comments(indent_level, options)
        lines << options.indented(indent_level, "interface #{name}")
        lines += generate_body(indent_level + 1, options)
        lines << options.indented(indent_level, "end")
      end

      sig { override.returns(String) }
      # Returns a human-readable brief string description of this interface.
      # @return [String]
      def describe
        "Interface #{name} - #{children.length}"
      end
    end
  end
end

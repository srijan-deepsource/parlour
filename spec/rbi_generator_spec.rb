# typed: ignore
RSpec.describe Parlour::RbiGenerator do
  def fix_heredoc(x)
    lines = x.lines
    /^( *)/ === lines.first
    indent_amount = $1.length
    lines.map do |line|
      /^ +$/ === line[0...indent_amount] \
        ? line[indent_amount..-1]
        : line
    end.join.rstrip
  end

  def pa(*a, **kw)
    Parlour::RbiGenerator::Parameter.new(*a, **kw)
  end

  def opts
    Parlour::Options.new(break_params: 4, tab_size: 2, sort_namespaces: false)
  end

  it 'has a root namespace' do
    expect(subject.root).to be_a Parlour::RbiGenerator::Namespace
  end

  context 'module namespace' do
    it 'generates an empty module correctly' do
      mod = subject.root.create_module('Foo')

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module Foo
        end
      RUBY
    end

    it 'can be final' do
      mod = subject.root.create_module('Foo', final: true)

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module Foo
          final!
        end
      RUBY
    end

    it 'can be sealed' do
      mod = subject.root.create_module('Foo', sealed: true)

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module Foo
          sealed!
        end
      RUBY
    end
  end

  context 'class namespace' do
    it 'generates an empty class correctly' do
      klass = subject.root.create_class('Foo')

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
        end
      RUBY
    end

    it 'can be final' do
      klass = subject.root.create_class('Foo', final: true)

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          final!
        end
      RUBY
    end

    it 'can be sealed' do
      klass = subject.root.create_class('Foo', sealed: true)

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          sealed!
        end
      RUBY
    end

    it 'nests classes correctly' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar') do |bar|
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
        foo.create_class('Baz', final: true) do |baz|
          baz.create_class('A')
          baz.create_class('B')
          baz.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            class A
            end

            class B
            end

            class C
            end
          end

          class Baz
            final!

            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end

    it 'handles abstract' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar', abstract: true) do |bar|
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            abstract!

            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end

    it 'handles includes, extends and constants' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_class('Bar', abstract: true) do |bar|
          bar.create_extend( 'X')
          bar.create_extend( 'Y')
          bar.create_include( 'Z')
          bar.create_type_alias('Text', type: 'T.any(String, Symbol)')
          bar.create_constant('PI', value: '3.14')
          bar.create_class('A')
          bar.create_class('B')
          bar.create_class('C')
        end
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          class Bar
            abstract!

            include Z
            extend X
            extend Y
            Text = T.type_alias { T.any(String, Symbol) }
            PI = 3.14

            class A
            end

            class B
            end

            class C
            end
          end
        end
      RUBY
    end

    it 'handles multiple includes and extends' do
      klass = subject.root.create_class('Foo') do |foo|
        foo.create_extends(['X', 'Y', 'Z'])
        foo.create_includes(['A', 'B', 'C'])
      end

      expect(klass.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class Foo
          include A
          include B
          include C
          extend X
          extend Y
          extend Z
        end
      RUBY
    end
  end

  context 'methods' do
    it 'have working equality' do
      expect(subject.root.create_method('foo')).to eq \
        subject.root.create_method('foo')

      expect(subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String')).to eq subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String')

      expect(subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String')).not_to eq subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '5')
      ], return_type: 'String')
    end

    it 'can be created blank' do
      meth = subject.root.create_method('foo')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { void }
        def foo; end
      RUBY
    end

    it 'can be created with return types' do
      meth = subject.root.create_method('foo', return_type: 'String')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { returns(String) }
        def foo; end
      RUBY
    end

    it 'can accept keyword alias for return types' do
      expect(subject.root.create_method('foo', returns: 'String')).to eq \
        subject.root.create_method('foo', return_type: 'String')
    end

    it 'cannot accept both returns: and return_type:' do
      expect do
        subject.root.create_method('foo', returns: 'String', return_type: 'String')
      end.to raise_error(RuntimeError)
    end

    it 'can be created with parameters' do
      meth = subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { params(a: Integer).returns(String) }
        def foo(a = 4); end
      RUBY

      meth = subject.root.create_method('bar', parameters: [
        pa('a'),
        pa('b', type: 'String'),
        pa('c', default: '3'),
        pa('d', type: 'Integer', default: '4')
      ], return_type: nil)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig do
          params(
            a: T.untyped,
            b: String,
            c: T.untyped,
            d: Integer
          ).void
        end
        def bar(a, b, c = 3, d = 4); end
      RUBY
    end

    it 'can be created with qualifiers' do
      meth = subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String', override: true, overridable: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { override.overridable.params(a: Integer).returns(String) }
        def foo(a = 4); end
      RUBY
    end

    it 'translates implementation to override (backwards compatibility)' do
      meth = subject.root.create_method('foo', parameters: [],
        return_type: 'String', implementation: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { override.returns(String) }
        def foo; end
      RUBY
    end

    it 'supports class methods' do
      meth = subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String', class_method: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { params(a: Integer).returns(String) }
        def self.foo(a = 4); end
      RUBY
    end

    it 'can be final' do
      meth = subject.root.create_method('foo', parameters: [
        pa('a', type: 'Integer', default: '4')
      ], return_type: 'String', final: true)

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig(:final) { params(a: Integer).returns(String) }
        def foo(a = 4); end
      RUBY
    end

    it 'supports type parameters' do
      meth = subject.root.create_method('box', type_parameters: [:A], parameters: [
        pa('a', type: 'T.type_parameter(:A)')
      ], return_type: 'T::Array[T.type_parameter(:A)]')

      expect(meth.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        sig { type_parameters(:A).params(a: T.type_parameter(:A)).returns(T::Array[T.type_parameter(:A)]) }
        def box(a); end
      RUBY
    end
  end

  context 'attributes' do
    it 'can be created using #create_attribute' do
      mod = subject.root.create_module('M') do |m|
        m.create_attribute('r', kind: :reader, type: 'String')
        m.create_attribute('w', kind: :writer, type: 'Integer')
        m.create_attr('a', kind: :accessor, type: 'T::Boolean') # test alias too
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          sig { returns(String) }
          attr_reader :r

          sig { params(w: Integer).returns(Integer) }
          attr_writer :w

          sig { returns(T::Boolean) }
          attr_accessor :a
        end
      RUBY
    end

    it 'can be created using #create_attr_writer etc' do
      mod = subject.root.create_module('M') do |m|
        m.create_attr_reader('r', type: 'String')
        m.create_attr_writer('w', type: 'Integer')
        m.create_attr_accessor('a', type: 'T::Boolean')
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          sig { returns(String) }
          attr_reader :r

          sig { params(w: Integer).returns(Integer) }
          attr_writer :w

          sig { returns(T::Boolean) }
          attr_accessor :a
        end
      RUBY
    end

    it 'supports class attributes' do
      mod = subject.root.create_class('A') do |m|
        m.create_attr_accessor('a', type: 'String', class_attribute: true)
        m.create_attr_accessor('b', type: 'Integer')
        m.create_attr_accessor('c', type: 'T::Boolean', class_attribute: true)
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class A
          class << self
            sig { returns(String) }
            attr_accessor :a

            sig { returns(T::Boolean) }
            attr_accessor :c
          end

          sig { returns(Integer) }
          attr_accessor :b
        end
      RUBY
    end
  end

  context 'enums' do
    it 'can be created' do
      mod = subject.root.create_module('M') do |m|
        m.create_enum_class('Directions', enums: ['North', 'South', 'West', ['East', '"Some custom serialization"']]) do |c|
          c.create_method('mnemonic', returns: 'String', class_method: true)
        end
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          class Directions < T::Enum
            enums do
              North = new
              South = new
              West = new
              East = new("Some custom serialization")
            end

            sig { returns(String) }
            def self.mnemonic; end
          end
        end
      RUBY
    end
  end

  context 'arbitrary code' do
    it 'is generated correctly for single lines' do
      mod = subject.root.create_module('M') do |m|
        m.create_arbitrary(code: 'some_call')
        m.create_method('foo')
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          some_call

          sig { void }
          def foo; end
        end
      RUBY
    end

    it 'is generated correctly for multiple lines' do
      mod = subject.root.create_module('M') do |m|
        m.create_arbitrary(code: "foo\nbar\nbaz")
        m.create_method('foo')
      end

      expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module M
          foo
          bar
          baz

          sig { void }
          def foo; end
        end
      RUBY
    end
  end

  it 'supports comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment('This is a module')
      m.create_class('A') do |a|
        a.add_comment('This is a class')
        a.create_method('foo') do |foo|
          foo.add_comment('This is a method')
        end
      end
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a module
      module M
        # This is a class
        class A
          # This is a method
          sig { void }
          def foo; end
        end
      end
    RUBY
  end

  it 'supports multi-line comments' do
    mod = subject.root.create_module('M') do |m|
      m.add_comment(['This is a', 'multi-line', 'comment'])
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a
      # multi-line
      # comment
      module M
      end
    RUBY
  end

  it 'supports comments on the next child' do
    subject.root.add_comment_to_next_child('This is a module')
    mod = subject.root.create_module('M') do |m|
      m.add_comment('This was added internally')
      m.add_comment_to_next_child('This is a class')
      m.create_class('A') do |a|
        a.add_comment_to_next_child('This is a method')
        a.create_method('foo')
      end
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      # This is a module
      # This was added internally
      module M
        # This is a class
        class A
          # This is a method
          sig { void }
          def foo; end
        end
      end
    RUBY
  end

  context '#path' do
    before :all do
      ::PathA = Module.new
      ::PathA::B = Module.new
      ::PathA::B::C = Class.new
      ::PathB = Class.new do
        def self.name
          "Foo"
        end

        def self.to_s
          name
        end
      end
      ::PathC = Class.new do
        def self.class
          Module
        end
      end
    end

    it 'generates correctly' do
      subject.root.path(::PathA::B::C) do |c|
        c.create_method('foo')
      end

      expect(subject.root.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        module PathA
          module B
            class C
              sig { void }
              def foo; end
            end
          end
        end
      RUBY
    end

    it 'throws on a non-root namespace' do
      expect { subject.root.create_module('X').path(::PathA::B::C) { |*| } }.to raise_error(RuntimeError)
    end

    it 'uses the actual constant name' do
      subject.root.path(::PathB) do |c|
        c.create_method('foo')
      end

      expect(subject.root.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class PathB
          sig { void }
          def foo; end
        end
      RUBY
    end

    it 'fails on constants that do not have a name' do
      constant = Module.new

      expect { subject.root.path(constant) { |*| } }.to raise_error(RuntimeError)
    end

    it 'works properly on constants that lie about their class' do
      subject.root.path(::PathC) do |c|
        c.create_method('foo')
      end

      expect(subject.root.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
        class PathC
          sig { void }
          def foo; end
        end
      RUBY
    end
  end

  it 'allows a strictness level to be specified' do
    expect(subject.rbi).to match /^\# typed: strong/
    expect(subject.rbi('true')).to match /^\# typed: true/
  end

  it 'supports sorting output' do
    custom_rbi_gen = Parlour::RbiGenerator.new(sort_namespaces: true)
    custom_opts = Parlour::Options.new(
      break_params: 4,
      tab_size: 2,
      sort_namespaces: true
    )

    m = custom_rbi_gen.root.create_module('M', interface: true)
    m.create_include('Y')
    m.create_module('B')
    m.create_method('c', parameters: [], return_type: nil)
    m.create_class('A') do |a|
      a.create_method('c')
      a.create_module('A')
      a.create_class('B')
    end
    m.create_arbitrary(code: '"some arbitrary code"')
    m.create_include('X')
    m.create_arbitrary(code: '"some more"')
    m.create_extend('Z')

    expect(custom_rbi_gen.root.generate_rbi(0, custom_opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      module M
        interface!

        include X
        include Y
        extend Z

        "some arbitrary code"

        "some more"

        class A
          module A
          end

          class B
          end

          sig { void }
          def c; end
        end

        module B
        end

        sig { void }
        def c; end
      end
    RUBY
  end

  it 'supports structs' do
    mod = subject.root.create_module('M') do |m|
      m.create_struct_class('Person', props: [
        Parlour::RbiGenerator::StructProp.new('name', 'String'),
        Parlour::RbiGenerator::StructProp.new('age', 'Integer', optional: true),
        Parlour::RbiGenerator::StructProp.new('prefers_light_theme', 'T::Boolean', default: 'false'),
      ]) do |person|
        person.create_method('theme', returns: 'String')
      end
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      module M
        class Person < T::Struct
          prop :name, String
          prop :age, Integer, optional: true
          prop :prefers_light_theme, T::Boolean, default: false

          sig { returns(String) }
          def theme; end
        end
      end
    RUBY
  end

  it 'supports eigenclass constants' do
    mod = subject.root.create_module('M') do |m|
      m.create_constant("X", value: "3", eigen_constant: true)
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      module M
        class << self
          X = 3
        end
      end
    RUBY
  end

  it 'supports multiple "class << self" constructs' do
    mod = subject.root.create_module('M') do |m|
      m.create_attr_reader("foo", type: "String", class_attribute: true)
      m.create_constant("X", value: "3", eigen_constant: true)
    end

    expect(mod.generate_rbi(0, opts).join("\n")).to eq fix_heredoc(<<-RUBY)
      module M
        class << self
          X = 3

          sig { returns(String) }
          attr_reader :foo
        end
      end
    RUBY
  end

  it 'implements the Searchable mixin' do
    mod = subject.root.create_module('M') do |m|
      m.create_class('A') do |a|
        a.create_class('B')
      end
      m.create_module('C')
      m.create_class('D')
    end

    expect(mod.find(name: 'A').name).to eq 'A'
    expect(mod.find(name: 'A').find(name: 'B').name).to eq 'B'
    expect(mod.find(name: 'C').name).to eq 'C'
    expect(mod.find(type: Parlour::RbiGenerator::ModuleNamespace).name).to eq 'C'

    expect(mod.find_all(name: 'A').map(&:name)).to eq ['A']
    expect(mod.find_all(type: Parlour::RbiGenerator::ClassNamespace).map(&:name)).to eq ['A', 'D']
  end
end

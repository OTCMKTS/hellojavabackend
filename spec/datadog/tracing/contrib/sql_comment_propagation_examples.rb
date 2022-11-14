RSpec.shared_examples_for 'with sql comment propagation' do |span_op_name:, error: nil|
  context 'when default `disabled`' do
    it_behaves_like 'propagates with sql comment', mode: 'disabled', span_op_name: span_op_name, error: error do
      let(:propagation_mode) { Datadog::Tracing::Contrib::Propagation::SqlComment::Mode.new('disabled') }
    end
  end

  context 'when ENV variable `DD_DBM_PROPAGATION_MODE` is provided' do
    around do |example|
      ClimateControl.modify(
        'DD_DBM_PROPAGATION_MODE' => 'service',
        &example
      )
    end

    it_behaves_like 'propagates with sql comment', mode: 'service', span_op_name: span_op_name, error: error do
      let(:propagation_mode) { Datadog::Tracing::Contrib::Propagation::SqlComment::Mode.new('service') }
    end
  end

  %w[disabled service full].each do |mode|
    context "when `comment_propagation` is configured to #{mode}" do
      let(:configuration_options) do
        { comment_propagation: mode, service_name: service_name }
      end

      it_behaves_like 'propagates with sql comment', mode: mode, span_op_name: span_op_name, error: error do
        let(:propagation_mode) { Datadog::Tracing::Contrib::Propagation::SqlComment::Mode.new(mode) }
      end
    end
  end
end

RSpec.shared_examples_for 'propagates with sql comment' do |mode:, span_op_name:, error: nil|
  it "propagates with mode: #{mode}" do
    expect(Datadog::Tracing::Contrib::Propagation::SqlComment::Mode)
      .to r
require_relative "test_helper"

require "network/clients/network_proposal"

class DummyLanItems
  def summary(params)
    params == "one_line" ? "one line summary" : "rich_text_summary"
  end
end

class DummyLan
  def Summary(_)
    ["rich_text_summary"]
  end
end

describe Yast::NetworkProposal do
  subject { Yast::NetworkProposal.new }

  let(:lan_items_mock) { DummyLanItems.new }
  let(:lan_mock) { DummyLan.new }

  before do
    stub_const("Yast::LanItems", lan_items_mock)
    stub_const("Yast::Lan", lan_mock)
  end

  describe "#description" do
    it "returns a map with id, menu_title and rich_text_title " do
      expect(subject.description).to include("id", "menu_title", "rich_text_title")
    end
  end

  describe "#make_proposal" do
    it "returns a map with 'label_proposal' as an array with one line summary'" do
      expect(subject.make_proposal({})["label_proposal"]).to eql(["one line summary"])
    end

    it "returns a map with 'preformatted_proposal' as an array with the network summary'" do
      expect(subject.make_proposal({})["preformatted_proposal"]).to eql(["rich_text_summary"])
    end
  end

  describe "#ask_user" do
    Yast.import "Wizard"

    before do
      allow(Yast::Wizard)
    end

    it "launchs the inst_lan client forcing the manual configuration" do
      expect(Yast::WFM).to receive(:CallFunction).with("inst_lan", [{ "skip_detection" => true }])
      subject.ask_user({})
    end

    it "returns a map with 'workflow_sequence' as the result of the client output" do
      allow(Yast::WFM).to receive(:CallFunction)
        .with("inst_lan", [{ "skip_detection" => true }])
        .and_return("result")

      expect(subject.ask_user({})).to eql("workflow_sequence" => "result")
    end
  end
end

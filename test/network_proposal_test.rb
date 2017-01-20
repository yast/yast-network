require_relative "test_helper"

require "network/clients/network_proposal"

describe Yast::NetworkProposal do
  Yast.import "LanItems"
  Yast.import "Lan"

  before do
    stub_const("Yast::Wizard", double.as_null_object)
    allow(Yast::LanItems).to receive(:summary).with("one_line").and_return("one_line_summary")
    allow(Yast::Lan).to receive(:Summary).with("summary").and_return(["rich_text_summary"])
  end

  describe "#description" do
    it "returns a map with id, menu_title and rich_text_title " do
      expect(subject.description).to include("id", "menu_title", "rich_text_title")
    end
  end

  describe "#make_proposal" do
    it "returns a map with 'label_proposal' as an array with one line summary'" do
      expect(subject.make_proposal({})["label_proposal"]).to eql(["one_line_summary"])
    end

    it "returns a map with 'preformatted_proposal' as an array with the network summary'" do
      expect(subject.make_proposal({})["preformatted_proposal"]).to eql(["rich_text_summary"])
    end
  end

  describe "#ask_user" do
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

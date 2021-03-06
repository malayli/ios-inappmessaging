import Quick
import Nimble
@testable import RInAppMessaging

class InAppMessagingModuleSpec: QuickSpec {

    override func spec() {

        describe("InAppMessagingModule") {

            var iamModule: InAppMessagingModule!
            var configurationManager: ConfigurationManagerMock!
            var campaignsListManager: CampaignsListManagerMock!
            var impressionService: ImpressionServiceMock!
            var preferenceRepository: IAMPreferenceRepository!
            var campaignsValidator: CampaignsValidatorMock!
            var eventMatcher: EventMatcherMock!
            var readyCampaignDispatcher: CampaignDispatcherMock!
            var campaignTriggerAgent: CampaignTriggerAgentType!
            var campaignRepository: CampaignRepositoryMock!
            var router: RouterMock!
            var delegate: Delegate!

            beforeEach {
                configurationManager = ConfigurationManagerMock()
                campaignsListManager = CampaignsListManagerMock()
                impressionService = ImpressionServiceMock()
                preferenceRepository = IAMPreferenceRepository()
                campaignsValidator = CampaignsValidatorMock()
                eventMatcher = EventMatcherMock()
                readyCampaignDispatcher = CampaignDispatcherMock()
                campaignTriggerAgent = CampaignTriggerAgent(eventMatcher: eventMatcher,
                                                            readyCampaignDispatcher: readyCampaignDispatcher,
                                                            campaignsValidator: campaignsValidator)
                campaignRepository = CampaignRepositoryMock()
                router = RouterMock()
                delegate = Delegate()
                iamModule = InAppMessagingModule(configurationManager: configurationManager,
                                                 campaignsListManager: campaignsListManager,
                                                 impressionService: impressionService,
                                                 preferenceRepository: preferenceRepository,
                                                 eventMatcher: eventMatcher,
                                                 readyCampaignDispatcher: readyCampaignDispatcher,
                                                 campaignTriggerAgent: campaignTriggerAgent,
                                                 campaignRepository: campaignRepository,
                                                 router: router)
                iamModule.delegate = delegate
            }

            context("when calling initialize") {

                it("will call fetchAndSaveConfigData in ConfigurationManager") {
                    var fetchCalled = false
                    configurationManager.fetchCalledClosure = {
                        fetchCalled = true
                    }
                    iamModule.initialize { }

                    expect(fetchCalled).to(beTrue())
                }

                it("will not call fetchAndSaveConfigData in ConfigurationManager when initilized for the second time") {
                    iamModule.initialize { }
                    var fetchCalled = false
                    configurationManager.fetchCalledClosure = {
                        fetchCalled = true
                    }
                    iamModule.initialize { }

                    expect(fetchCalled).to(beFalse())
                }

                context("and module is enabled") {
                    beforeEach {
                        configurationManager.isConfigEnabled = true
                    }

                    it("will call refreshList in CampaignsListManager") {
                        configurationManager.isConfigEnabled = true
                        iamModule.initialize { }

                        expect(campaignsListManager.wasRefreshListCalled).to(beTrue())
                    }

                    it("will not call deinit handler") {
                        var deinitCalled = false
                        iamModule.initialize {
                            deinitCalled = true
                        }

                        expect(deinitCalled).toAfterTimeout(beFalse())
                    }
                }

                context("and module is disabled") {
                    beforeEach {
                        configurationManager.isConfigEnabled = false
                    }

                    it("will not call refreshList in CampaignsListManager") {
                        iamModule.initialize { }

                        expect(campaignsListManager.wasRefreshListCalled).to(beFalse())
                    }

                    it("will call deinit handler") {
                        var deinitCalled = false
                        iamModule.initialize {
                            deinitCalled = true
                        }

                        expect(deinitCalled).to(beTrue())
                    }
                }

                context("when calling logEvent") {

                    context("and module is enabled") {
                        beforeEach {
                            configurationManager.isConfigEnabled = true
                        }

                        context("and module is initialized") {
                            beforeEach {
                                iamModule.initialize { }
                            }

                            it("will call EventMatcher") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(eventMatcher.loggedEvents).toEventually(haveCount(1))
                            }

                            it("will validate campaigns") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(campaignsValidator.wasValidateCalled).to(beTrue())
                            }

                            it("will trigger campaigns that should be triggered") {
                                let campaigns = [TestHelpers.generateCampaign(id: "1"),
                                                 TestHelpers.generateCampaign(id: "2")]
                                campaignsValidator.campaignsToTrigger = campaigns
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(readyCampaignDispatcher.addedCampaigns).to(equal(campaigns))
                            }

                            it("will call dispatchAllIfNeeded") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(readyCampaignDispatcher.wasDispatchCalled).to(beTrue())
                            }
                        }

                        context("and module is not initialized") {

                            it("will call EventMatcher") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(eventMatcher.loggedEvents).toEventually(haveCount(1))
                            }

                            it("will not validate campaigns") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(campaignsValidator.wasValidateCalled).toAfterTimeout(beFalse())
                            }

                            it("will not call dispatchAllIfNeeded") {
                                iamModule.logEvent(PurchaseSuccessfulEvent())
                                expect(readyCampaignDispatcher.wasDispatchCalled).toAfterTimeout(beFalse())
                            }
                        }
                    }

                    context("and module is disabled") {
                        beforeEach {
                            configurationManager.isConfigEnabled = false
                            iamModule.initialize { }
                        }

                        it("will not call EventMatcher") {
                            iamModule.logEvent(PurchaseSuccessfulEvent())
                            expect(eventMatcher.loggedEvents.isEmpty).toAfterTimeout(beTrue())
                        }

                        it("will not validate campaigns") {
                            iamModule.logEvent(PurchaseSuccessfulEvent())
                            expect(campaignsValidator.wasValidateCalled).toAfterTimeout(beFalse())
                        }

                        it("will not call dispatchAllIfNeeded") {
                            iamModule.logEvent(PurchaseSuccessfulEvent())
                            expect(readyCampaignDispatcher.wasDispatchCalled).toAfterTimeout(beFalse())
                        }
                    }
                }

                context("when calling registerPreference") {

                    context("and module is enabled") {
                        beforeEach {
                            configurationManager.isConfigEnabled = true
                        }

                        context("and module is initialized") {
                            beforeEach {
                                iamModule.initialize { }
                            }

                            it("will register preference data") {
                                let preference = IAMPreferenceBuilder().setUserId("user").build()
                                iamModule.registerPreference(preference)
                                expect(preferenceRepository.preference).to(equal(preference))
                            }

                            it("will refresh list of campaigns") {
                                iamModule.registerPreference(IAMPreference())
                                expect(campaignsListManager.wasRefreshListCalled).to(beTrue())
                            }
                        }

                        context("and module is not initialized") {

                            it("will register preference data") {
                                let preference = IAMPreferenceBuilder().setUserId("user").build()
                                iamModule.registerPreference(preference)
                                expect(preferenceRepository.preference).to(equal(preference))
                            }

                            it("will not refresh list of campaigns") {
                                iamModule.registerPreference(IAMPreference())
                                expect(campaignsListManager.wasRefreshListCalled).toAfterTimeout(beFalse())
                            }
                        }
                    }

                    context("and module is disabled") {
                        beforeEach {
                            configurationManager.isConfigEnabled = false
                            iamModule.initialize { }
                        }

                        it("will not register preference data") {
                            let preference = IAMPreferenceBuilder().setUserId("user").build()
                            iamModule.registerPreference(preference)
                            expect(preferenceRepository.preference).toAfterTimeout(beNil())
                        }

                        it("will not refresh list of campaigns") {
                            iamModule.registerPreference(IAMPreference())
                            expect(campaignsListManager.wasRefreshListCalled).toAfterTimeout(beFalse())
                        }
                    }
                }

                context("when calling closeMessage") {

                    it("will discard displayed campaign even if module is not initialized") {
                        iamModule.closeMessage(clearQueuedCampaigns: false)
                        expect(router.wasDiscardCampaignCalled).to(beTrue())
                    }

                    it("will increment impressionsLeft in closed campaign") {
                        let campaign = TestHelpers.generateCampaign(id: "test")
                        router.lastDisplayedCampaign = campaign

                        iamModule.closeMessage(clearQueuedCampaigns: false)
                        expect(campaignRepository.wasIncrementImpressionsCalled).to(beTrue())
                    }

                    it("will reset queued campaigns list if `clearQueuedCampaigns` is true") {
                        iamModule.closeMessage(clearQueuedCampaigns: true)
                        expect(readyCampaignDispatcher.wasResetQueueCalled).to(beTrue())
                    }

                    it("will not reset queued campaigns list if `clearQueuedCampaigns` is false") {
                        let campaign = TestHelpers.generateCampaign(id: "test")
                        router.lastDisplayedCampaign = campaign

                        iamModule.closeMessage(clearQueuedCampaigns: false)
                        expect(readyCampaignDispatcher.wasResetQueueCalled).to(beFalse())
                    }
                }

                context("as CampaignDispatcherDelegate") {

                    it("will refresh list of campaigns when performPing was called") {
                        iamModule.performPing()
                        expect(campaignsListManager.wasRefreshListCalled).to(beTrue())
                    }
                }

                context("as ErrorDelegate") {

                    var forwardedError: NSError?

                    beforeEach {
                        forwardedError = nil
                        iamModule.aggregatedErrorHandler = { error in
                            forwardedError = error
                        }
                    }

                    context("when configurationManager returned an error") {

                        it("will call aggregatedErrorHandler forwarding error object") {
                            configurationManager.reportError(description: "some error", data: Data())
                            expect(forwardedError).toNot(beNil())
                            expect(forwardedError?.localizedDescription).to(equal("InAppMessaging: some error"))
                            expect(forwardedError?.userInfo["data"] as? Data).to(equal(Data()))
                        }
                    }

                    context("when campaignsListManager returned an error") {

                        it("will call aggregatedErrorHandler forwarding error object") {
                            campaignsListManager.reportError(description: "some error", data: Data())
                            expect(forwardedError).toNot(beNil())
                            expect(forwardedError?.localizedDescription).to(equal("InAppMessaging: some error"))
                            expect(forwardedError?.userInfo["data"] as? Data).to(equal(Data()))
                        }
                    }

                    context("when impressionService returned an error") {

                        it("will call aggregatedErrorHandler forwarding error object") {
                            impressionService.reportError(description: "some error", data: Data())
                            expect(forwardedError).toNot(beNil())
                            expect(forwardedError?.localizedDescription).to(equal("InAppMessaging: some error"))
                            expect(forwardedError?.userInfo["data"] as? Data).to(equal(Data()))
                        }
                    }
                }
            }

            it("will return true for shouldShowCampaignMessage if delegate is nil") {
                iamModule.delegate = nil
                expect(iamModule.shouldShowCampaignMessage(title: "", contexts: [])).to(beTrue())
            }

            it("will call delegate method if shouldShowCampaignMessage was called") {
                _ = iamModule.shouldShowCampaignMessage(title: "", contexts: [])
                expect(delegate.wasShouldShowCampaignCalled).to(beTrue())
            }
        }
    }
}

private class Delegate: RInAppMessagingDelegate {
    var wasShouldShowCampaignCalled = false

    func inAppMessagingShouldShowCampaignWithContexts(contexts: [String], campaignTitle: String) -> Bool {
        wasShouldShowCampaignCalled = true
        return true
    }
}

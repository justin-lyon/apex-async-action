/**
 * Executes in chunks based on BatchSize.AsyncActionDefault Custom Metdata.
 * May use Constructor to pass alternate BatchSize DeveloperName.
 */
public with sharing class AsyncAction implements Queueable {
  private List<SObject> records;
  private AsyncActionItem action;
  private final String originalTransactionId;

  private static final String DEFAULT_ACTION_CONFIG = 'AsyncActionDefault';
  private final String batchSizeConfig;
  private BatchSizeService chunkService = new BatchSizeService();
  @TestVisible
  private void setBatchSizeService(BatchSizeService mock) {
    this.chunkService = mock;
  }

  private CollectionsUtil collections = new CollectionsUtil();

  public AsyncAction(List<SObject> records, AsyncActionItem ai, final String transactionId) {
    this(records, ai, transactionId, DEFAULT_ACTION_CONFIG);
  }

  public AsyncAction(List<SObject> records, AsyncActionItem ai, final String transactionId, final String configName) {
    this.records = records;
    this.action = ai;
    this.originalTransactionId = transactionId;
    this.batchSizeConfig = configName;
  }

  public void execute(QueueableContext ctx) {
    Nebula.Logger.setParentLogTransactionId(originalTransactionId);

    Integer chunkSize = (Integer) chunkService.getInstance(batchSizeConfig).Size__c;
    Integer listSize = records.size();
    Integer toProcessSliceUpperBound = listSize > chunkSize ? chunkSize : listSize;
    Integer toForwardSliceLowerBound = toProcessSliceUpperBound;
    Boolean isDone = listSize <= chunkSize;

    List<SObject> toProcess = (List<SObject>) collections.slice(records, 0, toProcessSliceUpperBound);
    Nebula.Logger.debug(new Nebula.LogMessage('Executing {0} records with AsyncActionItem {1}', toProcess.size(), action.getName()));
    action.execute(toProcess);

    if (!isDone) {
      List<SObject> toForward = (List<SObject>) collections.slice(records, toForwardSliceLowerBound, listSize);
      System.enqueueJob(new AsyncAction(toForward, action, originalTransactionId));
    }

    Nebula.Logger.saveLog();
  }
}

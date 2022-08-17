public interface AsyncActionItem {
  String getName();
  void execute(List<SObject> records);
}
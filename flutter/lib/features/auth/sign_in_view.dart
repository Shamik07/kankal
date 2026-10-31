import 'package:flutter/material.dart';
import 'package:kankal_ui/kankal_ui.dart';
import 'package:stacked/stacked.dart';

import '../../app/demo_account.dart';
import '../../core/auth/auth_api.dart';
import '../../core/diagnostics/diagnostics.dart';
import '../../app/routes.dart';
import 'sign_in_compact_view.dart';
import 'sign_in_view_model.dart';
import 'sign_in_wide_view.dart';

class SignInView extends StatelessWidget {
  const SignInView({
    super.key,
    required this.authApi,
    this.demoAccount,
    this.diagnostics = const NoopDiagnostics(),
  });

  final AuthApi authApi;
  final DemoAccount? demoAccount;
  final Diagnostics diagnostics;

  @override
  Widget build(BuildContext context) =>
      ViewModelBuilder<SignInViewModel>.reactive(
        viewModelBuilder: () => SignInViewModel(authApi, diagnostics),
        builder:
            (context, model, _) =>
                _SignInContent(model: model, demoAccount: demoAccount),
      );
}

class _SignInContent extends StatefulWidget {
  const _SignInContent({required this.model, required this.demoAccount});
  final SignInViewModel model;
  final DemoAccount? demoAccount;

  @override
  State<_SignInContent> createState() => _SignInContentState();
}

class _SignInContentState extends State<_SignInContent> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(
    text: widget.demoAccount?.email ?? '',
  );
  late final _password = TextEditingController(
    text: widget.demoAccount?.password ?? '',
  );
  final _code = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final model = widget.model;
    final wasCodeSubmission =
        model.method == SignInMethod.emailOtp && model.otpRequested;
    final success =
        model.method == SignInMethod.password
            ? await model.signInWithPassword(_email.text, _password.text)
            : model.otpRequested
            ? await model.signInWithOtp(_email.text, _code.text)
            : await model.requestOtp(_email.text);
    if (success &&
        mounted &&
        (model.method == SignInMethod.password || wasCodeSubmission)) {
      Navigator.of(
        context,
      ).pushNamedAndRemoveUntil(AppRoutes.items, (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.model;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final form = _form(context, model);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child:
                      constraints.maxWidth >= 720
                          ? SignInWideView(form: form)
                          : SignInCompactView(form: form),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _form(BuildContext context, SignInViewModel model) => Card(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Welcome back',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Choose how you’d like to sign in.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SegmentedButton<SignInMethod>(
              segments: const [
                ButtonSegment(
                  value: SignInMethod.password,
                  label: Text('Password'),
                ),
                ButtonSegment(
                  value: SignInMethod.emailOtp,
                  label: Text('Email code'),
                ),
              ],
              selected: {model.method},
              onSelectionChanged:
                  model.isBusy
                      ? null
                      : (selection) => model.selectMethod(selection.first),
            ),
            const SizedBox(height: 20),
            AppTextField(
              label: 'Email address',
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction:
                  model.method == SignInMethod.password
                      ? TextInputAction.next
                      : TextInputAction.done,
              validator:
                  (value) =>
                      value == null || !value.contains('@')
                          ? 'Enter a valid email address.'
                          : null,
            ),
            if (model.method == SignInMethod.password) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Password',
                controller: _password,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator:
                    (value) =>
                        value == null || value.isEmpty
                            ? 'Enter your password.'
                            : null,
              ),
            ],
            if (model.method == SignInMethod.emailOtp &&
                model.otpRequested) ...[
              const SizedBox(height: 16),
              AppTextField(
                label: 'Email code',
                controller: _code,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator:
                    (value) =>
                        value == null || value.trim().length != 6
                            ? 'Enter the six digit code.'
                            : null,
              ),
            ],
            if (model.errorMessage != null)
              _notice(model.errorMessage!, isError: true),
            if (model.successMessage != null) _notice(model.successMessage!),
            const SizedBox(height: 18),
            AppButton(
              label:
                  model.method == SignInMethod.emailOtp && !model.otpRequested
                      ? widget.demoAccount == null
                          ? 'Send code'
                          : 'Send demo code'
                      : 'Sign in',
              isBusy: model.isBusy,
              onPressed: model.isBusy ? null : _submit,
              expand: true,
            ),
            const SizedBox(height: 20),
            if (widget.demoAccount != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LOCAL DEMO • MOCK MODE',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Email  ${widget.demoAccount!.email}\nPassword  ${widget.demoAccount!.password}\nCode  ${widget.demoAccount!.code}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'No real email is sent. Data stays in this session.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  );

  Widget _notice(String message, {bool isError = false}) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Semantics(
      liveRegion: true,
      child: Text(
        message,
        style: TextStyle(
          color:
              isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
        ),
      ),
    ),
  );
}

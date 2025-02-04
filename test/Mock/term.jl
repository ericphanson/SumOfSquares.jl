config = MOI.Test.TestConfig()
optimize!(mock) = MOIU.mock_optimize!(mock, [0.0, 0.0],
    (MOI.VectorAffineFunction{Float64}, MOI.Nonnegatives) => [[1.0]],
    (MOI.VectorAffineFunction{Float64}, MOI.Zeros) => [[1.0]])
for mock in mocks(optimize!)
    Tests.sos_term_test(mock, config)
    Tests.sdsos_term_test(mock, config)
    Tests.dsos_term_test(mock, config)
end
